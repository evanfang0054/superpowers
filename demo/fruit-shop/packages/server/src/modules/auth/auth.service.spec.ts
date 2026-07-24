import { ConflictException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { AuthService } from './auth.service';

// Mock bcryptjs
jest.mock('bcryptjs');
const mockedBcrypt = bcrypt as jest.Mocked<typeof bcrypt>;

// Mock uuid (固定 jti 便于断言)
jest.mock('uuid', () => ({
  v4: jest.fn(() => 'fixed-jti'),
}));

describe('AuthService', () => {
  let service: AuthService;
  let userRepo: any;
  let jwtService: any;
  let configService: any;
  let redis: any;
  let logger: any;

  beforeEach(() => {
    userRepo = { findOne: jest.fn(), count: jest.fn(), create: jest.fn((x) => x), save: jest.fn() };
    jwtService = { sign: jest.fn(), verify: jest.fn(), decode: jest.fn() };
    configService = {
      get: jest.fn((k: string) => {
        if (k === 'JWT_SECRET') return 'test-secret';
        if (k === 'JWT_ACCESS_EXPIRES_IN') return '900';
        if (k === 'JWT_REFRESH_EXPIRES_IN') return '604800';
        return undefined;
      }),
    };
    redis = { get: jest.fn(), set: jest.fn() };
    logger = {
      setContext: jest.fn(),
      info: jest.fn(),
      warn: jest.fn(),
      error: jest.fn(),
      debug: jest.fn(),
    };
    service = new AuthService(userRepo, jwtService, configService, redis, logger);
    jest.clearAllMocks();
  });

  describe('register', () => {
    it('should set ADMIN for first user', async () => {
      userRepo.findOne.mockResolvedValue(null); // 手机号未注册
      userRepo.count.mockResolvedValue(0);
      mockedBcrypt.hash.mockResolvedValue('hashed' as never);
      jwtService.sign.mockReturnValue('token');
      userRepo.save.mockResolvedValue({ id: 1, phone: 'p', role: 'admin' });

      const result = await service.register({ phone: '13800000001', password: 'pass1234' });

      expect(userRepo.create).toHaveBeenCalledWith(expect.objectContaining({ role: 'admin' }));
      expect(result.user.role).toBe('admin');
      expect(result.accessToken).toBe('token');
    });

    it('should set USER for non-first user', async () => {
      userRepo.findOne.mockResolvedValue(null);
      userRepo.count.mockResolvedValue(5);
      mockedBcrypt.hash.mockResolvedValue('hashed' as never);
      jwtService.sign.mockReturnValue('token');
      userRepo.save.mockResolvedValue({ id: 2, phone: 'p', role: 'user' });

      const result = await service.register({ phone: '13800000002', password: 'pass1234' });

      expect(userRepo.create).toHaveBeenCalledWith(expect.objectContaining({ role: 'user' }));
    });

    it('should throw Conflict when phone exists', async () => {
      userRepo.findOne.mockResolvedValue({ id: 1 });
      await expect(
        service.register({ phone: '13800000001', password: 'pass1234' }),
      ).rejects.toThrow(ConflictException);
    });

    it('should hash password with salt 10', async () => {
      userRepo.findOne.mockResolvedValue(null);
      userRepo.count.mockResolvedValue(0);
      mockedBcrypt.hash.mockResolvedValue('hashed' as never);
      jwtService.sign.mockReturnValue('token');
      userRepo.save.mockResolvedValue({ id: 1, phone: 'p', role: 'admin' });
      await service.register({ phone: '13800000001', password: 'pass1234' });
      expect(mockedBcrypt.hash).toHaveBeenCalledWith('pass1234', 10);
    });
  });

  describe('login', () => {
    const buildQb = (user: any) => ({
      addSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      getOne: jest.fn().mockResolvedValue(user),
    });

    it('should throw Unauthorized when user not found', async () => {
      userRepo.createQueryBuilder = jest.fn(() => buildQb(null));
      await expect(service.login({ phone: 'p', password: 'x' })).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('should throw Unauthorized when password wrong', async () => {
      userRepo.createQueryBuilder = jest.fn(() =>
        buildQb({ id: 1, phone: 'p', password: 'hashed', role: 'user' }),
      );
      mockedBcrypt.compare.mockResolvedValue(false as never);
      await expect(service.login({ phone: 'p', password: 'wrong' })).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('should return tokens and user on success', async () => {
      userRepo.createQueryBuilder = jest.fn(() =>
        buildQb({ id: 1, phone: 'p', password: 'hashed', role: 'user' }),
      );
      mockedBcrypt.compare.mockResolvedValue(true as never);
      jwtService.sign.mockReturnValue('token');

      const result = await service.login({ phone: 'p', password: 'pass' });

      expect(result.accessToken).toBe('token');
      expect(result.refreshToken).toBe('token');
      expect(result.user).not.toHaveProperty('password');
    });
  });

  describe('refresh', () => {
    it('should throw when token type is not refresh', async () => {
      jwtService.verify.mockReturnValue({ sub: 1, type: 'access', jti: 'j' });
      await expect(service.refresh({ refreshToken: 't' })).rejects.toThrow(UnauthorizedException);
    });

    it('should throw when blacklisted', async () => {
      jwtService.verify.mockReturnValue({ sub: 1, type: 'refresh', jti: 'j' });
      redis.get.mockResolvedValue('1');
      await expect(service.refresh({ refreshToken: 't' })).rejects.toThrow(UnauthorizedException);
    });

    it('should throw when user not found', async () => {
      jwtService.verify.mockReturnValue({ sub: 1, type: 'refresh', jti: 'j' });
      redis.get.mockResolvedValue(null);
      userRepo.findOne.mockResolvedValue(null);
      await expect(service.refresh({ refreshToken: 't' })).rejects.toThrow(UnauthorizedException);
    });

    it('should throw when jwt.verify fails (expired)', async () => {
      jwtService.verify.mockImplementation(() => {
        throw new Error('expired');
      });
      await expect(service.refresh({ refreshToken: 't' })).rejects.toThrow(UnauthorizedException);
    });

    it('should return new accessToken on success', async () => {
      jwtService.verify.mockReturnValue({ sub: 1, type: 'refresh', jti: 'j' });
      redis.get.mockResolvedValue(null);
      userRepo.findOne.mockResolvedValue({ id: 1, phone: 'p', role: 'user' });
      jwtService.sign.mockReturnValue('new-at');

      const result = await service.refresh({ refreshToken: 't' });

      expect(result.accessToken).toBe('new-at');
    });
  });

  describe('logout', () => {
    it('should write blacklist with TTL when decode ok', async () => {
      const futureExp = Math.floor(Date.now() / 1000) + 3600;
      jwtService.decode.mockReturnValue({ exp: futureExp, jti: 'abc' });

      await service.logout(1, 'abc', 'Bearer t');

      expect(redis.set).toHaveBeenCalledWith('token:blacklist:abc', '1', 'EX', expect.any(Number));
    });

    it('should noop when decode returns null', async () => {
      jwtService.decode.mockReturnValue(null);
      await service.logout(1, 'abc', 't');
      expect(redis.set).not.toHaveBeenCalled();
    });

    it('should noop when ttl <= 0', async () => {
      const pastExp = Math.floor(Date.now() / 1000) - 100;
      jwtService.decode.mockReturnValue({ exp: pastExp });
      await service.logout(1, 'abc', 't');
      expect(redis.set).not.toHaveBeenCalled();
    });

    it('should swallow decode error silently', async () => {
      jwtService.decode.mockImplementation(() => {
        throw new Error('decode fail');
      });
      const r = await service.logout(1, 'abc', 't');
      expect(r).toBeNull();
    });
  });
});
