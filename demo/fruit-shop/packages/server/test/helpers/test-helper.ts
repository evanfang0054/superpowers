import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { AppModule } from '../../src/app.module';
import { TransformInterceptor } from '../../src/common/interceptors/transform.interceptor';
import { HttpExceptionFilter } from '../../src/common/filters/http-exception.filter';
import { DataSource } from 'typeorm';
import request from 'supertest';
import { Server } from 'http';

export class TestHelper {
  app: INestApplication;
  httpServer: Server;

  async setup() {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    this.app = moduleFixture.createNestApplication();
    this.app.setGlobalPrefix('api');
    this.app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
        transformOptions: { enableImplicitConversion: true },
      }),
    );
    // 与 main.ts 保持一致：通过 DI 获取 interceptor/filter，确保 Reflector/PinoLogger 正确注入
    this.app.useGlobalInterceptors(this.app.get(TransformInterceptor));
    this.app.useGlobalFilters(this.app.get(HttpExceptionFilter));

    await this.app.init();
    this.httpServer = this.app.getHttpServer();
  }

  async teardown() {
    if (this.app) {
      await this.app.close();
    }
  }

  /**
   * 清空 e2e 测试相关表，避免跨 run 数据污染（手机号已注册等）。
   * 不清 categories / products：这些是种子数据，且 e2e 依赖其存在。
   */
  async cleanDatabase() {
    const dataSource = this.app.get(DataSource);
    await dataSource.query('SET FOREIGN_KEY_CHECKS = 0');
    await dataSource.query('TRUNCATE TABLE order_items');
    await dataSource.query('TRUNCATE TABLE orders');
    await dataSource.query('TRUNCATE TABLE carts');
    await dataSource.query('TRUNCATE TABLE user_coupons');
    await dataSource.query('TRUNCATE TABLE coupon_templates');
    await dataSource.query('TRUNCATE TABLE users');
    await dataSource.query('SET FOREIGN_KEY_CHECKS = 1');
  }

  /**
   * 注册用户并返回 auth tokens
   */
  async registerAndLogin(
    phone = '13800000001',
    password = 'test123456',
    nickname?: string,
  ): Promise<{ accessToken: string; refreshToken: string; userId: number }> {
    const body: any = { phone, password };
    if (nickname) body.nickname = nickname;

    const res = await request(this.httpServer).post('/api/auth/register').send(body);

    // 响应被 TransformInterceptor 包装: { code: 0, data: { accessToken, refreshToken, user } }
    // 注册失败时显式抛错，避免下游 TypeError，便于定位 DB 污染等问题
    if (res.body?.code !== 0 || !res.body?.data?.user) {
      throw new Error(
        `registerAndLogin(${phone}) failed: code=${res.body?.code} message=${res.body?.message}`,
      );
    }
    const { accessToken, refreshToken, user } = res.body.data;
    return { accessToken, refreshToken, userId: user.id };
  }

  /**
   * 以 ADMIN 身份注册并登录（第一个注册的用户自动成为 ADMIN）
   */
  async registerAdmin(phone = '13900000001', password = 'admin123456') {
    return this.registerAndLogin(phone, password, 'Admin');
  }

  /**
   * 以 admin 身份创建商品，返回新商品 id
   */
  async createProductAsAdmin(token: string, overrides: Record<string, any> = {}): Promise<number> {
    const body = {
      name: overrides.name ?? `测试商品-${Date.now()}`,
      origin: overrides.origin ?? '测试产地',
      price: overrides.price ?? 19.9,
      unit: overrides.unit ?? '斤',
      sweetness: overrides.sweetness ?? '甜',
      weight: overrides.weight ?? '1kg',
      image: overrides.image ?? 'http://example.com/test.jpg',
      color: overrides.color ?? '#FF6B35',
      categoryId: overrides.categoryId ?? 1,
      stock: overrides.stock ?? 100,
      ...overrides,
    };
    const res = await request(this.httpServer)
      .post('/api/products')
      .set('Authorization', `Bearer ${token}`)
      .send(body);
    if (res.body?.code !== 0) {
      throw new Error(
        `createProductAsAdmin failed: code=${res.body?.code} message=${res.body?.message}`,
      );
    }
    return res.body.data.id;
  }

  /**
   * 以指定用户身份加入购物车
   */
  async addToCartAsUser(
    token: string,
    productId: number,
    specLabel: string,
    quantity: number,
  ): Promise<void> {
    const res = await request(this.httpServer)
      .post('/api/cart')
      .set('Authorization', `Bearer ${token}`)
      .send({ productId, specLabel, quantity });
    if (res.body?.code !== 0) {
      throw new Error(
        `addToCartAsUser failed: code=${res.body?.code} message=${res.body?.message}`,
      );
    }
  }

  /**
   * 读取商品当前库存（直接查 DB）
   */
  async getProductStock(productId: number): Promise<number> {
    const dataSource = this.app.get(DataSource);
    const rows: any[] = await dataSource.query('SELECT stock FROM products WHERE id = ?', [
      productId,
    ]);
    return rows.length > 0 ? Number(rows[0].stock) : -1;
  }

  /**
   * 直接修改商品库存（绕过 service，用于测试前置条件）
   */
  async setProductStock(productId: number, stock: number): Promise<void> {
    const dataSource = this.app.get(DataSource);
    await dataSource.query('UPDATE products SET stock = ? WHERE id = ?', [stock, productId]);
  }
}
