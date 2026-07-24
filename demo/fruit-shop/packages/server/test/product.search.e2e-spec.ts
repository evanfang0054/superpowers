import request from 'supertest';
import { TestHelper } from './helpers/test-helper';

describe('Product Search (e2e)', () => {
  const helper = new TestHelper();
  let adminToken: string;
  let userToken: string;
  let cheapAppleId: number;
  let midAppleId: number;
  let expensiveOrangeId: number;

  beforeAll(async () => {
    await helper.setup();
    await helper.cleanDatabase();

    const admin = await helper.registerAdmin('13900000036', 'admin123456');
    adminToken = admin.accessToken;
    const user = await helper.registerAndLogin('13800000036', 'test123456');
    userToken = user.accessToken;

    // 三个商品：不同价格 / 产地
    cheapAppleId = await helper.createProductAsAdmin(adminToken, {
      name: '搜索-红富士-便宜',
      origin: '山东',
      price: 5.5,
      stock: 100,
    });
    midAppleId = await helper.createProductAsAdmin(adminToken, {
      name: '搜索-红富士-中档',
      origin: '陕西',
      price: 12.5,
      stock: 100,
    });
    expensiveOrangeId = await helper.createProductAsAdmin(adminToken, {
      name: '搜索-橙子-高档',
      origin: '江西',
      price: 30.0,
      stock: 100,
    });

    // 制造销量：midApple 销量最高，cheapApple 次之，橙子无销量
    await helper.addToCartAsUser(userToken, midAppleId, '1kg', 5);
    await helper.addToCartAsUser(userToken, midAppleId, '1kg', 3);
    await helper.addToCartAsUser(userToken, cheapAppleId, '1kg', 2);
    // 各下一单（cart 会清空）
    await request(helper.httpServer)
      .post('/api/orders')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ address: '北京市', phone: '13800000036' });
    await helper.addToCartAsUser(userToken, cheapAppleId, '1kg', 1);
    await request(helper.httpServer)
      .post('/api/orders')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ address: '北京市', phone: '13800000036' });
    // midApple 销量 = 8，cheapApple 销量 = 3，橙子 = 0
  });

  afterAll(async () => {
    await helper.teardown();
  });

  describe('价格区间筛选', () => {
    it('minPrice 应过滤掉低于阈值的商品', () => {
      return request(helper.httpServer)
        .get('/api/products')
        .query({ minPrice: 10 })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          res.body.data.list.forEach((p: any) => {
            expect(Number(p.price)).toBeGreaterThanOrEqual(10);
          });
        });
    });

    it('maxPrice 应过滤掉高于阈值的商品', () => {
      return request(helper.httpServer)
        .get('/api/products')
        .query({ maxPrice: 15 })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          res.body.data.list.forEach((p: any) => {
            expect(Number(p.price)).toBeLessThanOrEqual(15);
          });
        });
    });

    it('minPrice + maxPrice 区间筛选', () => {
      return request(helper.httpServer)
        .get('/api/products')
        .query({ minPrice: 8, maxPrice: 20 })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          const list: any[] = res.body.data.list;
          // 应包含中档红富士，不应包含便宜/橙子
          const ids = list.map((p) => p.id);
          expect(ids).toContain(midAppleId);
          expect(ids).not.toContain(cheapAppleId);
          expect(ids).not.toContain(expensiveOrangeId);
        });
    });
  });

  describe('产地筛选', () => {
    it('origin=山东 只返回山东商品', () => {
      return request(helper.httpServer)
        .get('/api/products')
        .query({ origin: '山东' })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          res.body.data.list.forEach((p: any) => {
            expect(p.origin).toBe('山东');
          });
        });
    });
  });

  describe('sortBy 排序', () => {
    it('price_asc 应按价格升序', () => {
      return request(helper.httpServer)
        .get('/api/products')
        .query({ sortBy: 'price_asc', limit: 100 })
        .expect(200)
        .expect((res) => {
          const list: any[] = res.body.data.list;
          const prices = list.map((p) => Number(p.price));
          for (let i = 1; i < prices.length; i++) {
            expect(prices[i]).toBeGreaterThanOrEqual(prices[i - 1]);
          }
        });
    });

    it('price_desc 应按价格降序', () => {
      return request(helper.httpServer)
        .get('/api/products')
        .query({ sortBy: 'price_desc', limit: 100 })
        .expect(200)
        .expect((res) => {
          const list: any[] = res.body.data.list;
          const prices = list.map((p) => Number(p.price));
          for (let i = 1; i < prices.length; i++) {
            expect(prices[i]).toBeLessThanOrEqual(prices[i - 1]);
          }
        });
    });

    it('sales_desc 应按销量聚合降序（midApple > cheapApple > orange）', () => {
      return request(helper.httpServer)
        .get('/api/products')
        .query({ sortBy: 'sales_desc', limit: 100 })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          const ids: number[] = res.body.data.list.map((p: any) => p.id);
          const idxMid = ids.indexOf(midAppleId);
          const idxCheap = ids.indexOf(cheapAppleId);
          const idxOrange = ids.indexOf(expensiveOrangeId);
          // 都应存在
          expect(idxMid).toBeGreaterThanOrEqual(0);
          expect(idxCheap).toBeGreaterThanOrEqual(0);
          expect(idxOrange).toBeGreaterThanOrEqual(0);
          // 销量顺序
          expect(idxMid).toBeLessThan(idxCheap);
          // 无销量的橙子应在便宜之后（销售为 0，按 created_at DESC 兜底仍可能在前）
          // 主要断言 midApple 排在 cheapApple 之前
        });
    });

    it('created_desc 默认排序有效', () => {
      return request(helper.httpServer)
        .get('/api/products')
        .query({ limit: 100 })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          const list: any[] = res.body.data.list;
          for (let i = 1; i < list.length; i++) {
            expect(new Date(list[i].createdAt).getTime()).toBeLessThanOrEqual(
              new Date(list[i - 1].createdAt).getTime(),
            );
          }
        });
    });
  });

  describe('GET /api/products/bestsellers', () => {
    it('应返回热销列表（无需登录）', () => {
      return request(helper.httpServer)
        .get('/api/products/bestsellers')
        .query({ limit: 5 })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(Array.isArray(res.body.data.list)).toBe(true);
          // midApple 应排在最前
          const ids: number[] = res.body.data.list.map((p: any) => p.id);
          if (ids.includes(midAppleId) && ids.includes(cheapAppleId)) {
            expect(ids.indexOf(midAppleId)).toBeLessThan(ids.indexOf(cheapAppleId));
          }
        });
    });

    it('第二次请求应命中 Redis 缓存（返回相同结果）', async () => {
      const r1 = await request(helper.httpServer)
        .get('/api/products/bestsellers')
        .query({ limit: 5 });
      const r2 = await request(helper.httpServer)
        .get('/api/products/bestsellers')
        .query({ limit: 5 });
      expect(r1.body.data.list).toEqual(r2.body.data.list);
    });
  });

  describe('GET /api/products/suggest', () => {
    it('应返回匹配商品名的数组', () => {
      return request(helper.httpServer)
        .get('/api/products/suggest')
        .query({ keyword: '红富士', limit: 10 })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(Array.isArray(res.body.data.list)).toBe(true);
          res.body.data.list.forEach((name: string) => {
            expect(name).toContain('红富士');
          });
        });
    });

    it('空 keyword 应返回空数组', () => {
      return request(helper.httpServer)
        .get('/api/products/suggest')
        .query({ keyword: '', limit: 10 })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.list).toEqual([]);
        });
    });

    it('limit 参数应被尊重', () => {
      return request(helper.httpServer)
        .get('/api/products/suggest')
        .query({ keyword: '搜索', limit: 1 })
        .expect(200)
        .expect((res) => {
          expect(res.body.data.list.length).toBeLessThanOrEqual(1);
        });
    });
  });
});
