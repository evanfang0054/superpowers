import 'reflect-metadata';
import { join } from 'path';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { Logger } from 'nestjs-pino';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    bufferLogs: true,
  });

  // 使用 pino 作为全局 logger（覆盖 NestJS 内置 Logger）
  app.useLogger(app.get(Logger));

  // 全局路由前缀 — nginx 反向代理 /api/ → /api/
  app.setGlobalPrefix('api');

  // 全局 CORS — 通过 CORS_ORIGINS 环境变量配置，逗号分隔多个 origin
  const corsOrigins = process.env.CORS_ORIGINS;
  app.enableCors({
    origin: corsOrigins ? corsOrigins.split(',') : true,
    credentials: true,
  });

  // Swagger API 文档（可通过 SWAGGER_ENABLED=false 关闭）
  if (process.env.SWAGGER_ENABLED !== 'false') {
    const swaggerConfig = new DocumentBuilder()
      .setTitle('鲜果集 API')
      .setDescription('水果电商接口文档')
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup('api/docs', app, document);
  }

  // 全局 ValidationPipe — 自动 trim + 白名单 + 禁止多余字段
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  // 全局响应拦截器 — 包装 { code: 0, data, message: 'success' }
  app.useGlobalInterceptors(app.get(TransformInterceptor));

  // 全局异常过滤器 — 统一返回 { code, message }
  app.useGlobalFilters(app.get(HttpExceptionFilter));

  // 静态资源：/uploads/ 前缀指向 dist 同级的 uploads 目录
  app.useStaticAssets(join(__dirname, '..', 'uploads'), {
    prefix: '/uploads/',
  });

  const port = process.env.PORT || 3000;
  await app.listen(port);
  app.get(Logger).log(`Application is running on: http://localhost:${port}`);
}

bootstrap();
