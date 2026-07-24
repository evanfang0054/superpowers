import request from 'supertest';
import { DataSource } from 'typeorm';
import { TestHelper } from './helpers/test-helper';

describe('Address (e2e)', () => {
  const helper = new TestHelper();
  let tokenA: string;
  let userIdA: number;
  let tokenB: string;
  let addressId: number;
  let defaultAddressId: number;

  beforeAll(async () => {
    await helper.setup();
    await helper.cleanDatabase();

    const userA = await helper.registerAndLogin('13800000100', 'test123456', 'UserA');
    tokenA = userA.accessToken;
    userIdA = userA.userId;

    const userB = await helper.registerAndLogin('13800000101', 'test123456', 'UserB');
    tokenB = userB.accessToken;

    // 清空 addresses 表（cleanDatabase 不含）
    const dataSource = helper.app.get(DataSource);
    await dataSource.query('TRUNCATE TABLE addresses');
  });

  afterAll(async () => {
    await helper.teardown();
  });

  it('POST /api/addresses 应创建地址（非默认）', () => {
    return request(helper.httpServer)
      .post('/api/addresses')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        recipientName: '张三',
        phone: '13800000100',
        province: '北京市',
        city: '北京市',
        district: '朝阳区',
        detail: '建国路88号',
      })
      .expect(201)
      .expect((res) => {
        expect(res.body.code).toBe(0);
        expect(res.body.data.id).toBeDefined();
        expect(res.body.data.isDefault).toBe(false);
        addressId = res.body.data.id;
      });
  });

  it('POST /api/addresses 应创建默认地址，其他置非默认', async () => {
    const res = await request(helper.httpServer)
      .post('/api/addresses')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        recipientName: '李四',
        phone: '13800000100',
        province: '上海市',
        city: '上海市',
        district: '浦东新区',
        detail: '张江路100号',
        isDefault: true,
      })
      .expect(201);
    expect(res.body.code).toBe(0);
    expect(res.body.data.isDefault).toBe(true);
    defaultAddressId = res.body.data.id;

    // 之前那条应该已变为非默认
    const listRes = await request(helper.httpServer)
      .get('/api/addresses')
      .set('Authorization', `Bearer ${tokenA}`);
    const prev = listRes.body.data.find((a: any) => a.id === addressId);
    expect(prev.isDefault).toBe(false);
  });

  it('GET /api/addresses 应返回默认地址排首位', () => {
    return request(helper.httpServer)
      .get('/api/addresses')
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(0);
        expect(Array.isArray(res.body.data)).toBe(true);
        expect(res.body.data.length).toBeGreaterThanOrEqual(2);
        expect(res.body.data[0].isDefault).toBe(true);
      });
  });

  it('PUT /api/addresses/:id 应更新地址', () => {
    return request(helper.httpServer)
      .put(`/api/addresses/${addressId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ detail: '建国路99号修改' })
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(0);
        expect(res.body.data.detail).toBe('建国路99号修改');
      });
  });

  it('DELETE /api/addresses/:id 默认地址不可删除（返回 40902）', () => {
    return request(helper.httpServer)
      .delete(`/api/addresses/${defaultAddressId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(40902);
      });
  });

  it('PUT /api/addresses/:id/default 应切换默认地址', async () => {
    await request(helper.httpServer)
      .put(`/api/addresses/${addressId}/default`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(0);
        expect(res.body.data.isDefault).toBe(true);
      });

    // 验证原来的默认地址已变为非默认
    const listRes = await request(helper.httpServer)
      .get('/api/addresses')
      .set('Authorization', `Bearer ${tokenA}`);
    const oldDefault = listRes.body.data.find((a: any) => a.id === defaultAddressId);
    expect(oldDefault.isDefault).toBe(false);
  });

  it('DELETE /api/addresses/:id 非默认地址可删除', () => {
    return request(helper.httpServer)
      .delete(`/api/addresses/${defaultAddressId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(0);
      });
  });

  it('越权：UserB 不能更新 UserA 的地址', () => {
    return request(helper.httpServer)
      .put(`/api/addresses/${addressId}`)
      .set('Authorization', `Bearer ${tokenB}`)
      .send({ detail: 'hacked' })
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(40901);
      });
  });

  it('越权：UserB 不能删除 UserA 的地址', () => {
    return request(helper.httpServer)
      .delete(`/api/addresses/${addressId}`)
      .set('Authorization', `Bearer ${tokenB}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(40901);
      });
  });

  it('越权：UserB 不能把 UserA 的地址设默认', () => {
    return request(helper.httpServer)
      .put(`/api/addresses/${addressId}/default`)
      .set('Authorization', `Bearer ${tokenB}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(40901);
      });
  });

  it('无 token GET /api/addresses 返回 401', () => {
    return request(helper.httpServer)
      .get('/api/addresses')
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(401);
      });
  });

  it('手机号格式错误应被 ValidationPipe 拒绝', () => {
    return request(helper.httpServer)
      .post('/api/addresses')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        recipientName: '王五',
        phone: '12345',
        province: '北京市',
        city: '北京市',
        district: '海淀区',
        detail: '中关村',
      })
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(400);
      });
  });
});
