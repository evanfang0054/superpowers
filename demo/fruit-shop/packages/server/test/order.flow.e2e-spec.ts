import request from 'supertest';
import { DataSource } from 'typeorm';
import { TestHelper } from './helpers/test-helper';

describe('Order Flow (e2e)', () => {
  const helper = new TestHelper();
  let userToken: string;
  let adminToken: string;
  let orderId: number;

  beforeAll(async () => {
    await helper.setup();
    await helper.cleanDatabase();
    const admin = await helper.registerAdmin('13900000030', 'admin123456');
    adminToken = admin.accessToken;
    const user = await helper.registerAndLogin('13800000030', 'test123456');
    userToken = user.accessToken;

    // 清理 refunds/shippings（cleanDatabase 不含这两张表）
    const ds = helper.app.get(DataSource);
    await ds.query('SET FOREIGN_KEY_CHECKS = 0');
    await ds.query('TRUNCATE TABLE refunds');
    await ds.query('TRUNCATE TABLE shippings');
    await ds.query('SET FOREIGN_KEY_CHECKS = 1');
  });

  afterAll(async () => {
    await helper.teardown();
  });

  it('完整流转：下单 → 支付 → 发货 → 确认收货', async () => {
    const productId = await helper.createProductAsAdmin(adminToken, {
      name: '流转测试商品',
      stock: 10,
    });
    await helper.addToCartAsUser(userToken, productId, '默认', 1);
    const createRes = await request(helper.httpServer)
      .post('/api/orders')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ address: '北京市', phone: '13800000030' });
    expect(createRes.body.code).toBe(0);
    orderId = createRes.body.data.id;
    expect(createRes.body.data.status).toBe(0); // PENDING

    // 支付
    const payRes = await request(helper.httpServer)
      .put(`/api/orders/${orderId}/pay`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(payRes.body.code).toBe(0);
    expect(payRes.body.data.status).toBe(1);
    expect(payRes.body.data.paidAt).toBeTruthy();

    // Admin 发货
    const shipRes = await request(helper.httpServer)
      .post(`/api/orders/admin/${orderId}/ship`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ company: '顺丰', trackingNo: 'SF123456' });
    expect(shipRes.body.code).toBe(0);
    expect(shipRes.body.data.status).toBe(2);
    expect(shipRes.body.data.shippedAt).toBeTruthy();

    // 查物流
    const shippingRes = await request(helper.httpServer)
      .get(`/api/orders/${orderId}/shipping`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(shippingRes.body.code).toBe(0);
    expect(shippingRes.body.data.company).toBe('顺丰');

    // 确认收货
    const confirmRes = await request(helper.httpServer)
      .put(`/api/orders/${orderId}/confirm`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(confirmRes.body.code).toBe(0);
    expect(confirmRes.body.data.status).toBe(3); // COMPLETED
  });

  it('非法流转：PAID 不可再次支付', async () => {
    const res = await request(helper.httpServer)
      .put(`/api/orders/${orderId}/pay`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(res.body.code).toBe(40402); // ORDER_STATUS_ERROR
  });

  it('非法流转：PENDING 不可发货', async () => {
    const productId = await helper.createProductAsAdmin(adminToken, {
      stock: 5,
    });
    await helper.addToCartAsUser(userToken, productId, '默认', 1);
    const createRes = await request(helper.httpServer)
      .post('/api/orders')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ address: '北京市', phone: '13800000030' });
    const newOrderId = createRes.body.data.id;
    const res = await request(helper.httpServer)
      .post(`/api/orders/admin/${newOrderId}/ship`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ company: '顺丰', trackingNo: 'SF999' });
    expect(res.body.code).toBe(40402);
  });

  it('退款流程：申请 → 通过（库存回补）', async () => {
    const productId = await helper.createProductAsAdmin(adminToken, {
      name: '退款商品',
      stock: 5,
    });
    await helper.addToCartAsUser(userToken, productId, '默认', 2);
    const stockBefore = await helper.getProductStock(productId);

    const createRes = await request(helper.httpServer)
      .post('/api/orders')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ address: '北京市', phone: '13800000030' });
    const refundOrderId = createRes.body.data.id;
    const stockAfterOrder = await helper.getProductStock(productId);
    expect(stockAfterOrder).toBe(stockBefore - 2);

    await request(helper.httpServer)
      .put(`/api/orders/${refundOrderId}/pay`)
      .set('Authorization', `Bearer ${userToken}`);
    const refundReqRes = await request(helper.httpServer)
      .post(`/api/orders/${refundOrderId}/refund`)
      .set('Authorization', `Bearer ${userToken}`)
      .send({ reason: '商品损坏' });
    expect(refundReqRes.body.code).toBe(0);
    expect(refundReqRes.body.data.status).toBe(5); // REFUNDING

    // Admin 查退款列表（显式传 status=0 PENDING，规避 controller @Query 转换边界）
    const listRes = await request(helper.httpServer)
      .get('/api/admin/refunds?status=0')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(listRes.body.code).toBe(0);
    const refundId = listRes.body.data.list[0].id;

    // 通过退款
    const approveRes = await request(helper.httpServer)
      .post(`/api/admin/refunds/${refundId}/approve`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(approveRes.body.code).toBe(0);

    const stockAfterRefund = await helper.getProductStock(productId);
    expect(stockAfterRefund).toBe(stockBefore); // 回补
  });

  it('退款拒绝：恢复 prevStatus', async () => {
    const productId = await helper.createProductAsAdmin(adminToken, {
      stock: 10,
    });
    await helper.addToCartAsUser(userToken, productId, '默认', 1);
    const createRes = await request(helper.httpServer)
      .post('/api/orders')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ address: '北京市', phone: '13800000030' });
    const rejectOrderId = createRes.body.data.id;
    await request(helper.httpServer)
      .put(`/api/orders/${rejectOrderId}/pay`)
      .set('Authorization', `Bearer ${userToken}`);
    await request(helper.httpServer)
      .post(`/api/orders/${rejectOrderId}/refund`)
      .set('Authorization', `Bearer ${userToken}`)
      .send({ reason: '不想要了' });

    const listRes = await request(helper.httpServer)
      .get('/api/admin/refunds?status=0')
      .set('Authorization', `Bearer ${adminToken}`);
    const refundId = listRes.body.data.list[0].id;

    const rejectRes = await request(helper.httpServer)
      .post(`/api/admin/refunds/${refundId}/reject`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ adminNote: '不符合退款条件' });
    expect(rejectRes.body.code).toBe(0);

    // 订单恢复为 PAID
    const orderRes = await request(helper.httpServer)
      .get(`/api/orders/${rejectOrderId}`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(orderRes.body.data.status).toBe(1); // PAID
  });

  it('REFUNDING 状态的订单不可 cancel', async () => {
    // 创建订单 → pay → refund 申请 → 尝试 cancel 应失败
    const productId = await helper.createProductAsAdmin(adminToken, { stock: 10 });
    await helper.addToCartAsUser(userToken, productId, '默认', 1);
    const createRes = await request(helper.httpServer)
      .post('/api/orders')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ address: '北京市', phone: '13800000030' });
    const tempOrderId = createRes.body.data.id;

    await request(helper.httpServer)
      .put(`/api/orders/${tempOrderId}/pay`)
      .set('Authorization', `Bearer ${userToken}`);
    await request(helper.httpServer)
      .post(`/api/orders/${tempOrderId}/refund`)
      .set('Authorization', `Bearer ${userToken}`)
      .send({ reason: '测试' });

    // REFUNDING 状态下 cancel 应失败
    const cancelRes = await request(helper.httpServer)
      .put(`/api/orders/${tempOrderId}/cancel`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(cancelRes.body.code).toBe(40403); // ORDER_CANCEL_NOT_ALLOWED
  });
});
