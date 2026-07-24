import { ConfigService } from '@nestjs/config';
import { TypeOrmModuleOptions } from '@nestjs/typeorm';

export const databaseConfig = (
  configService: ConfigService,
): TypeOrmModuleOptions => {
  const dbSync = configService.get<string>('DB_SYNC', 'true');

  if (process.env.NODE_ENV === 'production' && dbSync !== 'false') {
    console.warn(
      '[WARNING] DB_SYNC is not explicitly disabled in production. ' +
      'Set DB_SYNC=false to prevent automatic schema changes.',
    );
  }

  return {
    type: 'mysql',
    host: configService.get<string>('DB_HOST', 'localhost'),
    port: configService.get<number>('DB_PORT', 3306),
    username: configService.get<string>('DB_USERNAME', 'root'),
    password: configService.get<string>('DB_PASSWORD', 'root123'),
    database: configService.get<string>('DB_DATABASE', 'fruit_shop'),
    autoLoadEntities: true,
    synchronize: dbSync === 'true',
    logging: configService.get<string>('DB_LOGGING', 'false') === 'true',
    timezone: '+08:00',
    charset: 'utf8mb4',
  };
};
