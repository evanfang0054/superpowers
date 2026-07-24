import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  Optional,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { SUCCESS_CODE } from 'shared';

export const SKIP_TRANSFORM_KEY = 'skipTransform';

/**
 * 统一成功响应格式
 * { code: 0, data: T, message: 'success' }
 */
export interface ApiResponseFormat<T> {
  code: number;
  data: T;
  message: string;
}

@Injectable()
export class TransformInterceptor<T> implements NestInterceptor<T, ApiResponseFormat<T>> {
  constructor(@Optional() private readonly reflector?: Reflector) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<ApiResponseFormat<T>> {
    const skipTransform = this.reflector?.get<boolean>(SKIP_TRANSFORM_KEY, context.getHandler());
    if (skipTransform) {
      return next.handle() as Observable<ApiResponseFormat<T>>;
    }

    return next.handle().pipe(
      map((data) => ({
        code: SUCCESS_CODE,
        data,
        message: 'success',
      })),
    );
  }
}
