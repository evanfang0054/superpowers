import { Reflector } from '@nestjs/core';
import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { JwtAuthGuard } from './jwt-auth.guard';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

describe('JwtAuthGuard', () => {
  let guard: JwtAuthGuard;
  let reflector: jest.Mocked<Reflector>;
  let superSpy: jest.SpyInstance;
  const originalSuper = (AuthGuard('jwt').prototype as any).canActivate;

  beforeEach(() => {
    reflector = { getAllAndOverride: jest.fn() } as any;
    guard = new JwtAuthGuard(reflector);
    // 直接在 AuthGuard 原型上 mock canActivate，避开双层原型链 spyOn 的脆弱性
    superSpy = jest.spyOn(AuthGuard('jwt').prototype as any, 'canActivate').mockReturnValue(true);
  });

  afterEach(() => {
    superSpy.mockRestore();
    // 双保险恢复
    (AuthGuard('jwt').prototype as any).canActivate = originalSuper;
  });

  const mockCtx = (handler: any, clazz: any): ExecutionContext =>
    ({ getHandler: () => handler, getClass: () => clazz }) as any;

  it('should return true when @Public', () => {
    reflector.getAllAndOverride.mockReturnValue(true);
    const ctx = mockCtx(() => {}, class T {});
    expect(guard.canActivate(ctx)).toBe(true);
  });

  it('should call super.canActivate when not @Public', () => {
    reflector.getAllAndOverride.mockReturnValue(false);
    const ctx = mockCtx(() => {}, class T {});
    expect(guard.canActivate(ctx)).toBe(true); // super mock 返回 true
    expect(superSpy).toHaveBeenCalled();
  });

  describe('handleRequest', () => {
    it('should rethrow err', () => {
      const err = new Error('boom');
      expect(() => guard.handleRequest(err, false, null)).toThrow(err);
    });

    it('should throw UnauthorizedException when no user no err', () => {
      expect(() => guard.handleRequest(null, false, null)).toThrow(UnauthorizedException);
    });

    it('should return user when valid', () => {
      const user = { id: 1 };
      expect(guard.handleRequest(null, user, null)).toBe(user);
    });
  });
});
