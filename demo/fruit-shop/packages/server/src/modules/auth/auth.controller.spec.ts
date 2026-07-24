import { Test, TestingModule } from '@nestjs/testing';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

describe('AuthController', () => {
  let controller: AuthController;
  let authService: jest.Mocked<AuthService>;

  const mockAuthService = {
    register: jest.fn(),
    login: jest.fn(),
    refresh: jest.fn(),
    logout: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [{ provide: AuthService, useValue: mockAuthService }],
    }).compile();

    controller = module.get<AuthController>(AuthController);
    authService = module.get(AuthService) as jest.Mocked<AuthService>;
    jest.clearAllMocks();
  });

  describe('POST /auth/register', () => {
    it('should register a new user', async () => {
      const dto = { phone: '13800000001', password: 'test123456' };
      const result = {
        accessToken: 'at',
        refreshToken: 'rt',
        user: { id: 1, phone: '13800000001' },
      };
      authService.register.mockResolvedValue(result as any);

      expect(await controller.register(dto)).toEqual(result);
      expect(authService.register).toHaveBeenCalledWith(dto);
    });
  });

  describe('POST /auth/login', () => {
    it('should login with valid credentials', async () => {
      const dto = { phone: '13800000001', password: 'test123456' };
      const result = {
        accessToken: 'at',
        refreshToken: 'rt',
        user: { id: 1, phone: '13800000001' },
      };
      authService.login.mockResolvedValue(result as any);

      expect(await controller.login(dto)).toEqual(result);
      expect(authService.login).toHaveBeenCalledWith(dto);
    });
  });

  describe('POST /auth/refresh', () => {
    it('should refresh access token', async () => {
      const dto = { refreshToken: 'valid-rt' };
      const result = { accessToken: 'new-at' };
      authService.refresh.mockResolvedValue(result as any);

      expect(await controller.refresh(dto)).toEqual(result);
      expect(authService.refresh).toHaveBeenCalledWith(dto);
    });
  });

  describe('POST /auth/logout', () => {
    it('should logout user', async () => {
      const user = { id: 1, jti: 'test-jti' };
      authService.logout.mockResolvedValue(null as any);

      // logout 方法需要 @Req() 和 @CurrentUser()，直接调用测试
      expect(
        await controller.logout(user, { headers: { authorization: 'Bearer test-token' } } as any),
      ).toBeNull();
      expect(authService.logout).toHaveBeenCalledWith(1, 'test-jti', 'test-token');
    });
  });
});
