import request from 'supertest';
import { DataSource } from 'typeorm';
import { TestHelper } from './helpers/test-helper';

describe('Favorite (e2e)', () => {
  const helper = new TestHelper();
  let adminToken: string;
  let userAToken: string;
  let userBToken: string;
  let userAId: number;
  let userBId: number;
  let productIdA: number;
  let productIdB: number;

  beforeAll(async () => {
    await helper.setup();
    await helper.cleanDatabase();

    const ds = helper.app.get(DataSource);
    await ds.query('SET FOREIGN_KEY_CHECKS = 0');
    await ds.query('TRUNCATE TABLE favorites');
    await ds.query('SET FOREIGN_KEY_CHECKS = 1');

    const admin = await helper.registerAdmin('13900000098', 'admin123456');
    adminToken = admin.accessToken;

    const a = await helper.registerAndLogin('13800000091', 'test123456', 'UserA');
    userAToken = a.accessToken;
    userAId = a.userId;

    const b = await helper.registerAndLogin('13800000092', 'test123456', 'UserB');
    userBToken = b.accessToken;
    userBId = b.userId;

    productIdA = await helper.createProductAsAdmin(adminToken, {
      name: '收藏测试商品A',
      stock: 10,
      price: 9.9,
    });
    productIdB = await helper.createProductAsAdmin(adminToken, {
      name: '收藏测试商品B',
      stock: 20,
      price: 19.9,
    });
  });

  afterAll(async () => {
    await helper.teardown();
  });

  describe('POST /api/products/:id/favorite', () => {
    it('UserA 收藏商品成功', async () => {
      const res = await request(helper.httpServer)
        .post(`/api/products/${productIdA}/favorite`)
        .set('Authorization', `Bearer ${userAToken}`);
      expect(res.body.code).toBe(0);
      expect(res.body.data.userId).toBe(userAId);
      expect(res.body.data.productId).toBe(productIdA);
      expect(res.body.data.id).toBeDefined();
    });

    it('重复收藏返回业务码 40801', async () => {
      const res = await request(helper.httpServer)
        .post(`/api/products/${productIdA}/favorite`)
        .set('Authorization', `Bearer ${userAToken}`);
      expect(res.body.code).toBe(40801); // FAVORITE_EXISTS
    });

    it('未登录返回 401', async () => {
      const res = await request(helper.httpServer).post(`/api/products/${productIdA}/favorite`);
      expect(res.body.code).toBe(401);
    });
  });

  describe('GET /api/products/:id/favorite-status', () => {
    it('已收藏返回 favorited=true', async () => {
      const res = await request(helper.httpServer)
        .get(`/api/products/${productIdA}/favorite-status`)
        .set('Authorization', `Bearer ${userAToken}`);
      expect(res.body.code).toBe(0);
      expect(res.body.data.favorited).toBe(true);
    });

    it('未收藏返回 favorited=false', async () => {
      const res = await request(helper.httpServer)
        .get(`/api/products/${productIdB}/favorite-status`)
        .set('Authorization', `Bearer ${userAToken}`);
      expect(res.body.code).toBe(0);
      expect(res.body.data.favorited).toBe(false);
    });

    it('越权：UserB 看 UserA 收藏的商品，应返回 false（仅查自己）', async () => {
      const res = await request(helper.httpServer)
        .get(`/api/products/${productIdA}/favorite-status`)
        .set('Authorization', `Bearer ${userBToken}`);
      expect(res.body.code).toBe(0);
      expect(res.body.data.favorited).toBe(false);
    });

    it('未登录返回 401', async () => {
      const res = await request(helper.httpServer).get(
        `/api/products/${productIdA}/favorite-status`,
      );
      expect(res.body.code).toBe(401);
    });
  });

  describe('GET /api/favorites', () => {
    it('UserA 再收藏一个商品用于列表测试', async () => {
      const res = await request(helper.httpServer)
        .post(`/api/products/${productIdB}/favorite`)
        .set('Authorization', `Bearer ${userAToken}`);
      expect(res.body.code).toBe(0);
    });

    it('UserA 列表应含 2 条，含 product 详情', async () => {
      const res = await request(helper.httpServer)
        .get('/api/favorites?page=1&limit=10')
        .set('Authorization', `Bearer ${userAToken}`);
      expect(res.body.code).toBe(0);
      expect(res.body.data.total).toBe(2);
      expect(res.body.data.list).toHaveLength(2);
      const item = res.body.data.list[0];
      expect(item.productId).toBeDefined();
      expect(item.product).toBeTruthy();
      expect(item.product.id).toBe(item.productId);
      expect(item.product.name).toMatch(/收藏测试商品/);
    });

    it('分页：limit=1 只返回 1 条，total 仍为 2', async () => {
      const res = await request(helper.httpServer)
        .get('/api/favorites?page=1&limit=1')
        .set('Authorization', `Bearer ${userAToken}`);
      expect(res.body.code).toBe(0);
      expect(res.body.data.total).toBe(2);
      expect(res.body.data.list).toHaveLength(1);
      expect(res.body.data.page).toBe(1);
      expect(res.body.data.limit).toBe(1);
    });

    it('UserB 列表应为空', async () => {
      const res = await request(helper.httpServer)
        .get('/api/favorites')
        .set('Authorization', `Bearer ${userBToken}`);
      expect(res.body.code).toBe(0);
      expect(res.body.data.total).toBe(0);
      expect(res.body.data.list).toHaveLength(0);
    });

    it('未登录返回 401', async () => {
      const res = await request(helper.httpServer).get('/api/favorites');
      expect(res.body.code).toBe(401);
    });
  });

  describe('DELETE /api/products/:id/favorite', () => {
    it('UserA 取消收藏商品B 成功', async () => {
      const res = await request(helper.httpServer)
        .delete(`/api/products/${productIdB}/favorite`)
        .set('Authorization', `Bearer ${userAToken}`);
      expect(res.body.code).toBe(0);
      expect(res.body.data.productId).toBe(productIdB);
    });

    it('取消收藏后列表只剩 1 条', async () => {
      const res = await request(helper.httpServer)
        .get('/api/favorites')
        .set('Authorization', `Bearer ${userAToken}`);
      expect(res.body.code).toBe(0);
      expect(res.body.data.total).toBe(1);
    });

    it('未收藏取消返回业务码 40802', async () => {
      const res = await request(helper.httpServer)
        .delete(`/api/products/${productIdB}/favorite`)
        .set('Authorization', `Bearer ${userAToken}`);
      expect(res.body.code).toBe(40802); // FAVORITE_NOT_FOUND
    });

    it('越权：UserB 取消 UserA 收藏的商品A 应返回 40802', async () => {
      const res = await request(helper.httpServer)
        .delete(`/api/products/${productIdA}/favorite`)
        .set('Authorization', `Bearer ${userBToken}`);
      expect(res.body.code).toBe(40802); // UserB 视角下不存在该收藏
    });

    it('未登录返回 401', async () => {
      const res = await request(helper.httpServer).delete(`/api/products/${productIdA}/favorite`);
      expect(res.body.code).toBe(401);
    });
  });
});
