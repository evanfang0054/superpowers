import request from 'supertest';
import { DataSource } from 'typeorm';
import { TestHelper } from './helpers/test-helper';

describe('Coupon (e2e)', () => {
  const helper = new TestHelper();
  let adminToken: string;
  let userAToken: string;
  let userBToken: string;
  let userAId: number;
  let userBId: number;
  let fullReductionCouponId: number; // type=0, minAmount=49, discountAmount=10
  let discountCouponId: number; // type=1, rate=0.9, minAmount=50
  let noThresholdCouponId: number; // type=2, discountAmount=5
  let productId: number;
  let productPrice = 29.9;
  let orderIdFromA: number;
  let usedCouponId: number;

  // 辅助：创建券
  async function createCoupon(payload: Record<string, any>): Promise<number> {
    const res = await request(helper.httpServer)
      .post('/api/admin/coupons')
      .set('Authorization', `Bearer ${adminToken}`)
      .send(payload);
    if (res.body?.code !== 0) {
      throw new Error(`createCoupon failed: code=${res.body?.code} message=${res.body?.message}`);
    }
    return res.body.data.id;
  }

  // 辅助：领券并返回 userCoupon DB id
  async function claimCoupon(token: string, couponId: number): Promise<number> {
    const res = await request(helper.httpServer)
      .post(`/api/coupons/${couponId}/claim`)
      .set('Authorization', `Bearer ${token}`);
    if (res.body?.code !== 0) {
      throw new Error(`claimCoupon failed: code=${res.body?.code} message=${res.body?.message}`);
    }
    return res.body.data.id;
  }

  // 辅助：添加商品到购物车
  async function addToCart(
    token: string,
    pId: number,
    quantity: number,
    specLabel = '1kg',
  ): Promise<void> {
    const res = await request(helper.httpServer)
      .post('/api/cart')
      .set('Authorization', `Bearer ${token}`)
      .send({ productId: pId, specLabel, quantity });
    if (res.body?.code !== 0) {
      throw new Error(`addToCart failed: code=${res.body?.code} message=${res.body?.message}`);
    }
  }

  // 辅助：查 user_coupon.id（DB 层）
  async function findUserCouponId(userId: number, couponId: number): Promise<number | null> {
    const ds = helper.app.get(DataSource);
    const rows: any[] = await ds.query(
      'SELECT id FROM user_coupons WHERE user_id = ? AND coupon_id = ? ORDER BY id DESC LIMIT 1',
      [userId, couponId],
    );
    return rows.length > 0 ? rows[0].id : null;
  }

  beforeAll(async () => {
    await helper.setup();
    await helper.cleanDatabase();

    const ds = helper.app.get(DataSource);
    await ds.query('SET FOREIGN_KEY_CHECKS = 0');
    await ds.query('TRUNCATE TABLE refunds');
    await ds.query('TRUNCATE TABLE shippings');
    await ds.query('SET FOREIGN_KEY_CHECKS = 1');

    // 注册：第一个 admin
    const admin = await helper.registerAdmin('13900000100', 'admin123456');
    adminToken = admin.accessToken;

    const userA = await helper.registerAndLogin('13800000100', 'test123456');
    userAToken = userA.accessToken;
    userAId = userA.userId;

    const userB = await helper.registerAndLogin('13800000101', 'test123456');
    userBToken = userB.accessToken;
    userBId = userB.userId;

    // 创建商品（categoryId=1）
    const pRes = await request(helper.httpServer)
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: '券测试商品',
        origin: '测试产地',
        price: productPrice,
        unit: '斤',
        sweetness: '甜',
        weight: '1kg',
        image: 'http://example.com/c.jpg',
        color: '#FF6B35',
        categoryId: 1,
        stock: 100,
      });
    expect(pRes.body.code).toBe(0);
    productId = pRes.body.data.id;

    // 创建三类券
    const now = new Date();
    const startAt = new Date(now.getTime() - 86400000).toISOString();
    const endAt = new Date(now.getTime() + 86400000).toISOString();

    fullReductionCouponId = await createCoupon({
      name: '满49减10',
      type: 0,
      minAmount: 49,
      discountAmount: 10,
      totalCount: 2,
      startAt,
      endAt,
    });
    discountCouponId = await createCoupon({
      name: '满50打9折',
      type: 1,
      minAmount: 50,
      discountRate: 0.9,
      totalCount: 10,
      startAt,
      endAt,
    });
    noThresholdCouponId = await createCoupon({
      name: '无门槛减5',
      type: 2,
      discountAmount: 5,
      totalCount: 10,
      startAt,
      endAt,
    });
  });

  afterAll(async () => {
    await helper.teardown();
  });

  describe('Admin CRUD', () => {
    it('GET /api/admin/coupons 返回模板列表', async () => {
      const res = await request(helper.httpServer)
        .get('/api/admin/coupons')
        .set('Authorization', `Bearer ${adminToken}`);
      expect(res.body.code).toBe(0);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBeGreaterThanOrEqual(3);
    });

    it('PUT /api/admin/coupons/:id 更新成功', async () => {
      const res = await request(helper.httpServer)
        .put(`/api/admin/coupons/${fullReductionCouponId}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ name: '满49减10（改名）' });
      expect(res.body.code).toBe(0);
      expect(res.body.data.name).toBe('满49减10（改名）');
    });

    it('非管理员不能访问 admin/coupons', async () => {
      const res = await request(helper.httpServer)
        .get('/api/admin/coupons')
        .set('Authorization', `Bearer ${userAToken}`);
      expect(res.body.code).not.toBe(0);
    });
  });

  describe('GET /api/coupons/available', () => {
    it('返回可领取列表', async () => {
      const res = await request(helper.httpServer)
        .get('/api/coupons/available')
        .set('Authorization', `Bearer ${userAToken}`);
      expect(res.body.code).toBe(0);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBeGreaterThanOrEqual(3);
      // 未领取时 claimed=false
      const target = res.body.data.find((c: any) => c.id === fullReductionCouponId);
      expect(target.claimed).toBe(false);
    });
  });

  describe('POST /api/coupons/:id/claim', () => {
    it('用户 A 领取成功，claimedCount++', async () => {
      const ds = helper.app.get(DataSource);
      const before: any[] = await ds.query(
        'SELECT claimed_count FROM coupon_templates WHERE id = ?',
        [fullReductionCouponId],
      );
      const beforeCount = Number(before[0].claimed_count);

      const ucId = await claimCoupon(userAToken, fullReductionCouponId);
      expect(ucId).toBeGreaterThan(0);

      const after: any[] = await ds.query(
        'SELECT claimed_count FROM coupon_templates WHERE id = ?',
        [fullReductionCouponId],
      );
      expect(Number(after[0].claimed_count)).toBe(beforeCount + 1);

      // available 列表里现在 claimed=true
      const res = await request(helper.httpServer)
        .get('/api/coupons/available')
        .set('Authorization', `Bearer ${userAToken}`);
      const target = res.body.data.find((c: any) => c.id === fullReductionCouponId);
      expect(target.claimed).toBe(true);
    });

    it('领取超限 COUPON_SOLD_OUT', async () => {
      // totalCount=2，已被 A 领 1 张；B 领 1 张（满额）
      await claimCoupon(userBToken, fullReductionCouponId);
      // 再领应失败
      const res = await request(helper.httpServer)
        .post(`/api/coupons/${fullReductionCouponId}/claim`)
        .set('Authorization', `Bearer ${userAToken}`);
      expect(res.body.code).toBe(41004);
    });
  });

  describe('GET /api/coupons/mine', () => {
    it('返回用户 A 的未使用券，含 template 详情', async () => {
      const res = await request(helper.httpServer)
        .get('/api/coupons/mine')
        .set('Authorization', `Bearer ${userAToken}`);
      expect(res.body.code).toBe(0);
      expect(Array.isArray(res.body.data.list)).toBe(true);
      expect(res.body.data.list.length).toBeGreaterThanOrEqual(1);
      const uc = res.body.data.list.find((x: any) => x.couponId === fullReductionCouponId);
      expect(uc).toBeDefined();
      expect(uc.coupon).toBeDefined();
      expect(uc.coupon.name).toContain('满49减10');
    });
  });

  describe('POST /api/coupons/preview', () => {
    const itemsFor = (qty: number) => [
      { productId, quantity: qty, price: productPrice, categoryId: 1 },
    ];

    it('满减券满足门槛：扣 10', async () => {
      const res = await request(helper.httpServer)
        .post('/api/coupons/preview')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ couponId: fullReductionCouponId, items: itemsFor(2) });
      expect(res.body.code).toBe(0);
      expect(Number(res.body.data.discountAmount)).toBe(10);
      // 29.9*2 - 10 = 49.8
      expect(Number(res.body.data.totalAfterDiscount)).toBeCloseTo(49.8, 2);
    });

    it('满减券不满足门槛：COUPON_MIN_NOT_MET', async () => {
      const res = await request(helper.httpServer)
        .post('/api/coupons/preview')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ couponId: fullReductionCouponId, items: itemsFor(1) });
      // 29.9 < 49
      expect(res.body.code).toBe(41005);
    });

    it('折扣券满足门槛：subtotal * 0.1', async () => {
      const res = await request(helper.httpServer)
        .post('/api/coupons/preview')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ couponId: discountCouponId, items: itemsFor(2) });
      expect(res.body.code).toBe(0);
      // subtotal = 59.8, discount = 59.8 * 0.1 = 5.98
      expect(Number(res.body.data.discountAmount)).toBeCloseTo(5.98, 2);
    });

    it('无门槛券：扣 5', async () => {
      const res = await request(helper.httpServer)
        .post('/api/coupons/preview')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ couponId: noThresholdCouponId, items: itemsFor(1) });
      expect(res.body.code).toBe(0);
      expect(Number(res.body.data.discountAmount)).toBe(5);
      // 29.9 - 5 = 24.9
      expect(Number(res.body.data.totalAfterDiscount)).toBeCloseTo(24.9, 2);
    });
  });

  describe('Order 集成：下单使用券', () => {
    it('用户 A 下单使用满减券：totalAmount 扣减 + UserCoupon 核销', async () => {
      // 购物车先加 2 件商品（subtotal=59.8）满足满49
      await addToCart(userAToken, productId, 2);

      const ucId = await findUserCouponId(userAId, fullReductionCouponId);
      expect(ucId).toBeTruthy();
      usedCouponId = ucId!;

      const res = await request(helper.httpServer)
        .post('/api/orders')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({
          address: '北京市朝阳区',
          phone: '13800000100',
          couponId: ucId,
        });
      expect(res.body.code).toBe(0);
      expect(res.body.data.id).toBeGreaterThan(0);
      expect(Number(res.body.data.totalAmount)).toBeCloseTo(49.8, 2);
      expect(Number(res.body.data.discountAmount)).toBe(10);
      expect(res.body.data.couponId).toBe(fullReductionCouponId);

      // DB 校验 user_coupon 已核销
      const ds = helper.app.get(DataSource);
      const ucRows: any[] = await ds.query(
        'SELECT used_at, order_id FROM user_coupons WHERE id = ?',
        [ucId],
      );
      expect(ucRows[0].used_at).not.toBeNull();
      expect(ucRows[0].order_id).toBe(res.body.data.id);

      orderIdFromA = res.body.data.id;
      usedCouponId = ucId as number;
    });

    it('重复使用同一已核销券：COUPON_USED', async () => {
      // 加新购物车后再下单用同一券
      await addToCart(userAToken, productId, 2);
      const res = await request(helper.httpServer)
        .post('/api/orders')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({
          address: '北京市朝阳区',
          phone: '13800000100',
          couponId: usedCouponId,
        });
      expect(res.body.code).toBe(41003);
    });

    it('越权：用户 B 不能使用用户 A 的 user_coupon', async () => {
      await addToCart(userBToken, productId, 2);
      const res = await request(helper.httpServer)
        .post('/api/orders')
        .set('Authorization', `Bearer ${userBToken}`)
        .send({
          address: '北京市朝阳区',
          phone: '13800000101',
          couponId: usedCouponId, // 属于 A
        });
      expect(res.body.code).toBe(41006);
    });

    it('取消订单 → 券解绑可再用', async () => {
      const cancelRes = await request(helper.httpServer)
        .put(`/api/orders/${orderIdFromA}/cancel`)
        .set('Authorization', `Bearer ${userAToken}`);
      expect(cancelRes.body.code).toBe(0);

      // DB 校验：user_coupon 解绑
      const ds = helper.app.get(DataSource);
      const ucRows: any[] = await ds.query(
        'SELECT used_at, order_id FROM user_coupons WHERE id = ?',
        [usedCouponId],
      );
      expect(ucRows[0].used_at).toBeNull();
      expect(ucRows[0].order_id).toBeNull();

      // 再次下单用该券应该成功
      await addToCart(userAToken, productId, 2);
      const reuseRes = await request(helper.httpServer)
        .post('/api/orders')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({
          address: '北京市朝阳区',
          phone: '13800000100',
          couponId: usedCouponId,
        });
      expect(reuseRes.body.code).toBe(0);
    });
  });
});
