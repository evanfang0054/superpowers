import request from 'supertest';
import { TestHelper } from './helpers/test-helper';

describe('User (e2e)', () => {
  const helper = new TestHelper();
  let accessToken: string;

  beforeAll(async () => {
    await helper.setup();
    await helper.cleanDatabase();
    const tokens = await helper.registerAndLogin('13800000010', 'test123456', 'TestUser');
    accessToken = tokens.accessToken;
  });

  afterAll(async () => {
    await helper.teardown();
  });

  describe('GET /api/user/profile', () => {
    it('should return user profile', () => {
      return request(helper.httpServer)
        .get('/api/user/profile')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.phone).toBe('13800000010');
          expect(res.body.data.nickname).toBe('TestUser');
        });
    });

    it('should reject unauthenticated request', () => {
      return request(helper.httpServer)
        .get('/api/user/profile')
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(401);
        });
    });
  });

  describe('PUT /api/user/profile', () => {
    it('should update nickname', () => {
      return request(helper.httpServer)
        .put('/api/user/profile')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ nickname: 'UpdatedName' })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.nickname).toBe('UpdatedName');
        });
    });

    it('should update avatar', () => {
      return request(helper.httpServer)
        .put('/api/user/profile')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ avatar: 'https://example.com/avatar.jpg' })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.avatar).toBe('https://example.com/avatar.jpg');
        });
    });
  });

  describe('权限与更新', () => {
    let userA: { accessToken: string; userId: number };
    let userB: { accessToken: string; userId: number };

    beforeAll(async () => {
      userA = await helper.registerAndLogin('13800000080', 'test123456', 'A');
      userB = await helper.registerAndLogin('13800000081', 'test123456', 'B');
    });

    it('should reject no-token GET /user/profile (401)', () => {
      return request(helper.httpServer)
        .get('/api/user/profile')
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(401);
        });
    });

    it('should update own nickname', () => {
      return request(helper.httpServer)
        .put('/api/user/profile')
        .set('Authorization', `Bearer ${userA.accessToken}`)
        .send({ nickname: 'New Nickname' })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.nickname).toBe('New Nickname');
        });
    });

    it('should not leak B profile to A token (based on JWT userId)', () => {
      // A 的 token 只能查 A 自己的 profile
      return request(helper.httpServer)
        .get('/api/user/profile')
        .set('Authorization', `Bearer ${userA.accessToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.id).toBe(userA.userId);
          expect(res.body.data.id).not.toBe(userB.userId);
        });
    });
  });
});
