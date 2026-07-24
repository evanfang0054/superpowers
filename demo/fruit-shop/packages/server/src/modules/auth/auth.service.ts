import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  Inject,
  OnModuleInit,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Redis } from 'ioredis';
import { PinoLogger } from 'nestjs-pino';
import * as bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';
import { UserEntity } from '../../entities/user.entity';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import {
  UserRole,
  ErrorCode,
  ErrorMessage,
} from 'shared';

@Injectable()
export class AuthService implements OnModuleInit {
  constructor(
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    @Inject('REDIS_CLIENT')
    private readonly redis: Redis,
    private readonly logger: PinoLogger,
  ) {
    this.logger.setContext(AuthService.name);
  }

  onModuleInit() {
    const secret = this.configService.get<string>(
      'JWT_SECRET',
      'your-jwt-secret-change-in-prod',
    );

    const DEFAULT_SECRET = 'your-jwt-secret-change-in-prod';
    if (secret === DEFAULT_SECRET) {
      if (process.env.NODE_ENV === 'production') {
        throw new Error(
          '[FATAL] JWT_SECRET is using the default value in production. ' +
          'Set a strong random string via JWT_SECRET environment variable.',
        );
      }
      console.warn(
        '[WARNING] JWT_SECRET is using the default value. ' +
        'This is unsafe for production. Set JWT_SECRET environment variable.',
      );
    }
  }

  /**
   * 注册
   * - 首个注册用户自动设为 admin
   * - bcrypt 加密密码 (salt rounds: 10)
   */
  async register(dto: RegisterDto) {
    // 检查手机号是否已注册
    const existing = await this.userRepo.findOne({
      where: { phone: dto.phone },
    });
    if (existing) {
      throw new ConflictException(ErrorMessage[ErrorCode.PHONE_EXISTS]);
    }

    // 判断是否为首个用户 → admin
    const userCount = await this.userRepo.count();
    const role = userCount === 0 ? UserRole.ADMIN : UserRole.USER;

    // bcrypt 加密
    const hashedPassword = await bcrypt.hash(dto.password, 10);

    const user = this.userRepo.create({
      phone: dto.phone,
      password: hashedPassword,
      nickname: dto.nickname ?? undefined,
      role,
    });
    await this.userRepo.save(user);

    // 生成 token
    const tokens = await this.generateTokens(user.id, user.phone, user.role);

    // 返回时不包含 password
    const { password: _, ...userWithoutPassword } = user;

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: userWithoutPassword,
    };
  }

  /**
   * 登录
   * - bcrypt 校验密码
   * - 返回 accessToken + refreshToken + user
   */
  async login(dto: LoginDto) {
    // 查找用户（需要 password 字段）
    const user = await this.userRepo
      .createQueryBuilder('u')
      .addSelect('u.password')
      .where('u.phone = :phone', { phone: dto.phone })
      .getOne();

    if (!user) {
      throw new UnauthorizedException(ErrorMessage[ErrorCode.AUTH_FAILED]);
    }

    // bcrypt 校验
    const isPasswordValid = await bcrypt.compare(dto.password, user.password);
    if (!isPasswordValid) {
      throw new UnauthorizedException(ErrorMessage[ErrorCode.AUTH_FAILED]);
    }

    // 生成 token
    const tokens = await this.generateTokens(user.id, user.phone, user.role);

    this.logger.info(
      { userId: user.id },
      '用户登录成功',
    );

    // 返回时排除 password
    const { password: _, ...userWithoutPassword } = user;

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: userWithoutPassword,
    };
  }

  /**
   * 刷新 Token
   * - 验证 refreshToken 有效性
   * - 返回新的 accessToken
   */
  async refresh(dto: RefreshTokenDto) {
    try {
      const payload = this.jwtService.verify(dto.refreshToken, {
        secret: this.configService.get<string>('JWT_SECRET', 'your-jwt-secret-change-in-prod'),
      });

      // 必须是 refresh 类型的 token
      if (payload.type !== 'refresh') {
        throw new UnauthorizedException(
          ErrorMessage[ErrorCode.REFRESH_TOKEN_INVALID],
        );
      }

      // 检查 refresh token 是否在黑名单中
      const isBlacklisted = await this.redis.get(
        `token:blacklist:${payload.jti}`,
      );
      if (isBlacklisted) {
        throw new UnauthorizedException(
          ErrorMessage[ErrorCode.REFRESH_TOKEN_INVALID],
        );
      }

      // 验证用户是否仍存在
      const user = await this.userRepo.findOne({
        where: { id: payload.sub },
      });
      if (!user) {
        throw new UnauthorizedException(
          ErrorMessage[ErrorCode.REFRESH_TOKEN_INVALID],
        );
      }

      // 仅返回新的 accessToken，refreshToken 不自动续期
      const accessToken = this.generateAccessToken(
        user.id,
        user.phone,
        user.role,
      );

      return { accessToken };
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        throw error;
      }
      throw new UnauthorizedException(
        ErrorMessage[ErrorCode.REFRESH_TOKEN_INVALID],
      );
    }
  }

  /**
   * 登出
   * - 将 accessToken 的 jti 加入 Redis 黑名单
   * - TTL = token 剩余过期时间（秒）
   */
  async logout(userId: number, jti: string, tokenRaw: string) {
    try {
      const decoded = this.jwtService.decode(tokenRaw) as {
        exp?: number;
      } | null;

      if (decoded?.exp) {
        const ttl = decoded.exp - Math.floor(Date.now() / 1000);
        if (ttl > 0) {
          await this.redis.set(
            `token:blacklist:${jti}`,
            '1',
            'EX',
            ttl,
          );

          this.logger.info(
            {
              userId,
              jti,
              ttl,
            },
            'JWT 已加入黑名单（登出）',
          );
        }
      }
    } catch {
      // 即使 decode 失败也静默处理，登出不应抛出异常
    }

    return null;
  }

  // ========== 私有方法 ==========

  /**
   * 生成 accessToken + refreshToken
   * accessToken:  15 min, payload 含 jti + type='access'
   * refreshToken: 7 days, payload 含 jti + type='refresh'
   */
  private async generateTokens(
    userId: number,
    phone: string,
    role: string,
  ) {
    const accessJti = uuidv4();
    const refreshJti = uuidv4();

    const accessExpiresIn = Number(
      this.configService.get<string>('JWT_ACCESS_EXPIRES_IN', '900'),
    ); // 15 min = 900s
    const refreshExpiresIn = Number(
      this.configService.get<string>('JWT_REFRESH_EXPIRES_IN', '604800'),
    ); // 7 days = 604800s

    const accessToken = this.jwtService.sign(
      {
        sub: userId,
        phone,
        role,
        jti: accessJti,
        type: 'access',
      },
      { expiresIn: accessExpiresIn },
    );

    const refreshToken = this.jwtService.sign(
      {
        sub: userId,
        phone,
        role,
        jti: refreshJti,
        type: 'refresh',
      },
      { expiresIn: refreshExpiresIn },
    );

    this.logger.debug(
      {
        userId,
        accessJti,
        refreshJti,
      },
      'JWT 签发',
    );

    return { accessToken, refreshToken };
  }

  private generateAccessToken(
    userId: number,
    phone: string,
    role: string,
  ): string {
    const accessJti = uuidv4();
    const accessExpiresIn = Number(
      this.configService.get<string>('JWT_ACCESS_EXPIRES_IN', '900'),
    );

    return this.jwtService.sign(
      {
        sub: userId,
        phone,
        role,
        jti: accessJti,
        type: 'access',
      },
      { expiresIn: accessExpiresIn },
    );
  }
}
