import { Controller, Get, Inject, SetMetadata } from '@nestjs/common';
import {
  HealthCheckService,
  HealthCheck,
  TypeOrmHealthIndicator,
  HealthIndicatorResult,
} from '@nestjs/terminus';
import { SkipThrottle } from '@nestjs/throttler';
import { Redis } from 'ioredis';
import { Public } from '../../common/decorators/public.decorator';
import { SKIP_TRANSFORM_KEY } from '../../common/interceptors/transform.interceptor';

@Controller('health')
export class HealthController {
  constructor(
    private readonly health: HealthCheckService,
    private readonly db: TypeOrmHealthIndicator,
    @Inject('REDIS_CLIENT') private readonly redis: Redis,
  ) {}

  @Get()
  @Public()
  @SkipThrottle()
  @HealthCheck()
  @SetMetadata(SKIP_TRANSFORM_KEY, true)
  check() {
    return this.health.check([() => this.db.pingCheck('database'), () => this.redisCheck()]);
  }

  private async redisCheck(): Promise<HealthIndicatorResult> {
    try {
      const result = await this.redis.ping();
      return { redis: { status: result === 'PONG' ? 'up' : 'down' } };
    } catch (error) {
      return { redis: { status: 'down', message: (error as Error).message } };
    }
  }
}
