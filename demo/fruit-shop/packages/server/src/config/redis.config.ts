import { ConfigService } from '@nestjs/config';
import { RedisModuleOptions } from '@nestjs-modules/ioredis';

export const redisConfig = (configService: ConfigService): RedisModuleOptions => {
  const options: RedisModuleOptions = {
    type: 'single',
    url: configService.get<string>(
      'REDIS_URL',
      `redis://${configService.get<string>('REDIS_HOST', 'localhost')}:${configService.get<number>('REDIS_PORT', 6379)}`,
    ),
  };

  // 测试环境通过 REDIS_DB 隔离 Redis（避免与 dev 共用 db 0）
  const redisDb = configService.get<string>('REDIS_DB');
  if (redisDb !== undefined) {
    options.options = { db: Number(redisDb) };
  }

  return options;
};
