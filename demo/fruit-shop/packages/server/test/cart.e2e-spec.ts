import request from 'supertest';
import { TestHelper } from './helpers/test-helper';

describe('Cart (e2e)', () => {
  const helper = new TestHelper();
  let userToken: string;
  let adminToken: string;
  let productId: number;

  beforeAll(async () => {
    await helper.setup();
    // 清空 users/carts/orders/order_items，保留 products/categories 种子数据
    await helper.cleanDatabase();

    // 第一个注册的用户自动获得 ADMIN 角色
    const admin = await helper.registerAdmin('13900000002', 'admin123456');
    adminToken = admin.accessToken;

    const user = await helper.registerAndLogin('13800000030', 'test123456');
    userToken = user.accessToken;

    // 创建一个测试商品（CategoryId=1 来自种子数据）
    const productRes = await request(helper.httpServer)
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: '购物车测试商品',
        origin: '测试产地',
        price: 19.9,
        unit: '斤',
        sweetness: '甜',
        weight: '500g',
        image: 'http://example.com/test.jpg',
        color: '#FF0000',
        categoryId: 1,
        stock: 50,
      });
    expect(productRes.body.code).toBe(0);
    productId = productRes.body.data.id;
  });

  afterAll(async () => {
    await helper.teardown();
  });

  describe('POST /api/cart', () => {
    it('should add item to cart', () => {
      return request(helper.httpServer)
        .post('/api/cart')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ productId, specLabel: '500g', quantity: 2 })
        .expect(201)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data).toBeInstanceOf(Array);
          expect(res.body.data.length).toBe(1);
          expect(res.body.data[0].quantity).toBe(2);
        });
    });

    it('should merge quantity for duplicate item', () => {
      return request(helper.httpServer)
        .post('/api/cart')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ productId, specLabel: '500g', quantity: 3 })
        .expect(201)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data[0].quantity).toBe(5); // 2 + 3
        });
    });

    it('should reject unauthenticated request', () => {
      return request(helper.httpServer)
        .post('/api/cart')
        .send({ productId, specLabel: '500g', quantity: 1 })
        .expect(200)
        .expect((res) => {
          // JwtAuthGuard 抛 UnauthorizedException(status 401) → code 401
          expect(res.body.code).toBe(401);
        });
    });
  });

  describe('GET /api/cart', () => {
    it('should return cart items', () => {
      return request(helper.httpServer)
        .get('/api/cart')
        .set('Authorization', `Bearer ${userToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data).toBeInstanceOf(Array);
          expect(res.body.data.length).toBe(1);
        });
    });

    it('should reject unauthenticated request', () => {
      return request(helper.httpServer)
        .get('/api/cart')
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(401);
        });
    });
  });

  describe('PUT /api/cart/:id', () => {
    let cartItemId: number;

    beforeAll(async () => {
      const res = await request(helper.httpServer)
        .get('/api/cart')
        .set('Authorization', `Bearer ${userToken}`);
      cartItemId = res.body.data[0].id;
    });

    it('should update cart item quantity', () => {
      return request(helper.httpServer)
        .put(`/api/cart/${cartItemId}`)
        .set('Authorization', `Bearer ${userToken}`)
        .send({ quantity: 10 })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.find((i: any) => i.id === cartItemId).quantity).toBe(10);
        });
    });

    it('should reject unauthenticated request', () => {
      return request(helper.httpServer)
        .put(`/api/cart/${cartItemId}`)
        .send({ quantity: 1 })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(401);
        });
    });

    it('should return 404 for non-existent cart item', () => {
      return request(helper.httpServer)
        .put('/api/cart/99999')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ quantity: 1 })
        .expect(200)
        .expect((res) => {
          // NotFoundException(status 404) → code 404
          expect(res.body.code).toBe(404);
        });
    });
  });

  describe('DELETE /api/cart/:id', () => {
    let cartItemId: number;

    beforeAll(async () => {
      const res = await request(helper.httpServer)
        .get('/api/cart')
        .set('Authorization', `Bearer ${userToken}`);
      cartItemId = res.body.data[0].id;
    });

    it('should remove cart item', () => {
      return request(helper.httpServer)
        .delete(`/api/cart/${cartItemId}`)
        .set('Authorization', `Bearer ${userToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.length).toBe(0);
        });
    });

    it('should return 404 when deleting already removed item', () => {
      return request(helper.httpServer)
        .delete(`/api/cart/${cartItemId}`)
        .set('Authorization', `Bearer ${userToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(404);
        });
    });
  });

  describe('越权与边界', () => {
    let userAToken: string;
    let userBToken: string;
    let userBCartId: number;

    beforeAll(async () => {
      userAToken = (await helper.registerAndLogin('13800000060', 'test123456')).accessToken;
      userBToken = (await helper.registerAndLogin('13800000061', 'test123456')).accessToken;

      // B 加一个商品到购物车
      const productIdForB = await helper.createProductAsAdmin(adminToken, {
        name: 'Cart 越权测试商品',
        price: 1,
        categoryId: 1,
        stock: 10,
        unit: '斤',
        origin: 'x',
        sweetness: '甜',
        weight: '1kg',
        image: 'i',
        color: '#fff',
      });
      await helper.addToCartAsUser(userBToken, productIdForB, '1kg', 1);

      // 从 B 的购物车列表取 cart id
      const listRes = await request(helper.httpServer)
        .get('/api/cart')
        .set('Authorization', `Bearer ${userBToken}`);
      userBCartId = listRes.body.data[0].id;
    });

    it('should reject adding non-existent product (404)', () => {
      return request(helper.httpServer)
        .post('/api/cart')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ productId: 999999, specLabel: '1kg', quantity: 1 })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(404);
        });
    });

    it('should reject A updating B cart (404)', () => {
      return request(helper.httpServer)
        .put(`/api/cart/${userBCartId}`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ quantity: 99 })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(404);
        });
    });

    it('should reject A deleting B cart (404)', () => {
      return request(helper.httpServer)
        .delete(`/api/cart/${userBCartId}`)
        .set('Authorization', `Bearer ${userAToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(404);
        });
    });

    it('should reject no-token GET /cart (401)', () => {
      return request(helper.httpServer)
        .get('/api/cart')
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(401);
        });
    });
  });
});
