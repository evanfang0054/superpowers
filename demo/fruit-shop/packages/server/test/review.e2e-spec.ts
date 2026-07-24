import request from 'supertest';
import { DataSource } from 'typeorm';
import { TestHelper } from './helpers/test-helper';

describe('Review (e2e)', () => {
  const helper = new TestHelper();
  let adminToken: string;
  let userAToken: string;
  let userBToken: string;
  let userAId: number;
  let userBId: number;

  let completedProductId: number;
  let completedOrderId: number;

  let pendingProductId: number;
  let pendingOrderId: number;

  beforeAll(async () => {
    await helper.setup();
    await helper.cleanDatabase();

    const ds = helper.app.get(DataSource);
    await ds.query('SET FOREIGN_KEY_CHECKS = 0');
    await ds.query('TRUNCATE TABLE reviews');
    await ds.query('SET FOREIGN_KEY_CHECKS = 1');

    const admin = await helper.registerAdmin('13900000088', 'admin123456');
    adminToken = admin.accessToken;

    const a = await helper.registerAndLogin('13800000081', 'test123456', 'UserA');
    userAToken = a.accessToken;
    userAId = a.userId;

    const b = await helper.registerAndLogin('13800000082', 'test123456', 'UserB');
    userBToken = b.accessToken;
    userBId = b.userId;
  });

  afterAll(async () => {
    await helper.teardown();
  });

  // 构造 COMPLETED 订单给 UserA
  it('setup: 创建 COMPLETED 订单供后续评价测试', async () => {
    completedProductId = await helper.createProductAsAdmin(adminToken, {
      name: '评价测试商品A',
      stock: 10,
    });
    await helper.addToCartAsUser(userAToken, completedProductId, '1kg', 1);
    const createRes = await request(helper.httpServer)
      .post('/api/orders')
      .set('Authorization', `Bearer ${userAToken}`)
      .send({ address: '北京市', phone: '13800000081' });
    expect(createRes.body.code).toBe(0);
    completedOrderId = createRes.body.data.id;

    await request(helper.httpServer)
      .put(`/api/orders/${completedOrderId}/pay`)
      .set('Authorization', `Bearer ${userAToken}`);
    await request(helper.httpServer)
      .post(`/api/orders/admin/${completedOrderId}/ship`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ company: '顺丰', trackingNo: 'RV1' });
    const confirmRes = await request(helper.httpServer)
      .put(`/api/orders/${completedOrderId}/confirm`)
      .set('Authorization', `Bearer ${userAToken}`);
    expect(confirmRes.body.code).toBe(0);
  });

  // 构造 PENDING 订单给 UserA（不可评价）
  it('setup: 创建 PENDING 订单供状态校验', async () => {
    pendingProductId = await helper.createProductAsAdmin(adminToken, {
      name: '评价测试商品B',
      stock: 10,
    });
    await helper.addToCartAsUser(userAToken, pendingProductId, '1kg', 1);
    const createRes = await request(helper.httpServer)
      .post('/api/orders')
      .set('Authorization', `Bearer ${userAToken}`)
      .send({ address: '北京市', phone: '13800000081' });
    expect(createRes.body.code).toBe(0);
    pendingOrderId = createRes.body.data.id;
  });

  describe('POST /api/orders/:id/reviews', () => {
    it('COMPLETED 订单评价成功', async () => {
      const res = await request(helper.httpServer)
        .post(`/api/orders/${completedOrderId}/reviews`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({
          reviews: [
            {
              productId: completedProductId,
              rating: 5,
              content: '很好吃',
              images: ['http://example.com/1.jpg'],
            },
          ],
        });
      expect(res.body.code).toBe(0);
      expect(res.body.data.created).toBe(1);
      expect(res.body.data.reviews[0].productId).toBe(completedProductId);
    });

    it('重复评价应返回业务码 40701', async () => {
      const res = await request(helper.httpServer)
        .post(`/api/orders/${completedOrderId}/reviews`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({
          reviews: [
            {
              productId: completedProductId,
              rating: 4,
              content: '再次评价',
            },
          ],
        });
      expect(res.body.code).toBe(40701); // REVIEW_EXISTS
    });

    it('未 COMPLETED 订单评价应返回 40702', async () => {
      const res = await request(helper.httpServer)
        .post(`/api/orders/${pendingOrderId}/reviews`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({
          reviews: [
            {
              productId: pendingProductId,
              rating: 5,
              content: 'x',
            },
          ],
        });
      expect(res.body.code).toBe(40702); // REVIEW_NOT_ALLOWED
    });

    it('越权：UserB 不可评价 UserA 的订单（404 ORDER_NOT_FOUND）', async () => {
      const res = await request(helper.httpServer)
        .post(`/api/orders/${completedOrderId}/reviews`)
        .set('Authorization', `Bearer ${userBToken}`)
        .send({
          reviews: [
            {
              productId: completedProductId,
              rating: 5,
              content: 'x',
            },
          ],
        });
      expect(res.body.code).toBe(404);
    });

    it('未登录 POST 评价应返回 401', async () => {
      const res = await request(helper.httpServer)
        .post(`/api/orders/${completedOrderId}/reviews`)
        .send({
          reviews: [{ productId: completedProductId, rating: 5, content: 'x' }],
        });
      expect(res.body.code).toBe(401);
    });
  });

  describe('GET /api/products/:id/reviews (@Public)', () => {
    it('应返回商品评价列表（含 userNickname）', async () => {
      const res = await request(helper.httpServer)
        .get(`/api/products/${completedProductId}/reviews`)
        .set('Authorization', `Bearer ${userAToken}`); // 任意 token，路由 @Public
      expect(res.body.code).toBe(0);
      expect(res.body.data.list.length).toBeGreaterThanOrEqual(1);
      const item = res.body.data.list[0];
      expect(item.productId).toBe(completedProductId);
      expect(item.userNickname).toBe('UserA');
    });

    it('无 token 也可访问', async () => {
      const res = await request(helper.httpServer).get(
        `/api/products/${completedProductId}/reviews`,
      );
      expect(res.body.code).toBe(0);
    });
  });

  describe('GET /api/reviews/mine', () => {
    it('UserA 应看到自己的评价', async () => {
      const res = await request(helper.httpServer)
        .get('/api/reviews/mine')
        .set('Authorization', `Bearer ${userAToken}`);
      expect(res.body.code).toBe(0);
      expect(res.body.data.list.length).toBeGreaterThanOrEqual(1);
      expect(res.body.data.list[0].userId).toBe(userAId);
    });

    it('UserB 暂无评价', async () => {
      const res = await request(helper.httpServer)
        .get('/api/reviews/mine')
        .set('Authorization', `Bearer ${userBToken}`);
      expect(res.body.code).toBe(0);
      expect(res.body.data.list.length).toBe(0);
    });

    it('未登录应返回 401', async () => {
      const res = await request(helper.httpServer).get('/api/reviews/mine');
      expect(res.body.code).toBe(401);
    });
  });
});
