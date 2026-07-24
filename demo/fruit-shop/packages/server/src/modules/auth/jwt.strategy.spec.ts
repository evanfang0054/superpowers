import { UnauthorizedException } from '@nestjs/common';
import { JwtStrategy } from './jwt.strategy';

// 直接实例化绕过 PassportStrategy super 的 secretOrKey 校验
describe('JwtStrategy.validate', () => {
  let strategy: any;
  let redis: any;

  beforeAll(() => {
    const configService: any = { get: jest.fn(() => 'secret') };
    redis = { get: jest.fn() };
    // 用 Object.create 绕过 super 构造
    strategy = Object.create(JwtStrategy.prototype);
    strategy.configService = configService;
    strategy.redis = redis;
  });

  it('should throw TOKEN_INVALID when type is not access', async () => {
    await expect(
      strategy.validate({ sub: 1, phone: 'p', role: 'user', jti: 'j', type: 'refresh' }),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('should throw TOKEN_EXPIRED when blacklisted', async () => {
    redis.get.mockResolvedValue('1');
    await expect(
      strategy.validate({ sub: 1, phone: 'p', role: 'user', jti: 'j', type: 'access' }),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('should return payload when valid', async () => {
    redis.get.mockResolvedValue(null);
    const result = await strategy.validate({
      sub: 1,
      phone: 'p',
      role: 'user',
      jti: 'j',
      type: 'access',
    });
    expect(result).toEqual({ id: 1, phone: 'p', role: 'user', jti: 'j' });
  });
});
