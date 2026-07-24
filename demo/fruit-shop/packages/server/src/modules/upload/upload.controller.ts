import {
  Controller,
  Post,
  UseInterceptors,
  UseGuards,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { ErrorCode, ErrorMessage } from 'shared';

const MAX_SIZE = 2 * 1024 * 1024; // 2MB

/**
 * 图片上传控制器
 *
 * 业务码：
 * - UPLOAD_FILE_TOO_LARGE(41101) — 超过 2MB（multer limits 落盘前的超限由
 *   fileFilter 二次判断保护，落盘后再校验一次）
 * - UPLOAD_INVALID_TYPE(41102) — 非 image/* MIME
 * - UPLOAD_FAILED(41103) — 缺少 file 字段
 */
@Controller('upload')
@UseGuards(JwtAuthGuard)
@UseInterceptors(
  FileInterceptor('file', {
    storage: diskStorage({
      destination: join(__dirname, '..', '..', '..', 'uploads'),
      filename: (_req, file, cb) => {
        const ext = extname(file.originalname) || '.png';
        const name = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
        cb(null, name);
      },
    }),
    fileFilter: (_req, file, cb) => {
      if (!file) {
        return cb(
          new BadRequestException({
            code: ErrorCode.UPLOAD_FAILED,
            message: ErrorMessage[ErrorCode.UPLOAD_FAILED],
          }),
          false,
        );
      }
      if (!file.mimetype || !file.mimetype.startsWith('image/')) {
        return cb(
          new BadRequestException({
            code: ErrorCode.UPLOAD_INVALID_TYPE,
            message: ErrorMessage[ErrorCode.UPLOAD_INVALID_TYPE],
          }),
          false,
        );
      }
      cb(null, true);
    },
  }),
)
export class UploadController {
  @Post('image')
  uploadImage(@UploadedFile() file: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException({
        code: ErrorCode.UPLOAD_FAILED,
        message: ErrorMessage[ErrorCode.UPLOAD_FAILED],
      });
    }
    if (file.size > MAX_SIZE) {
      throw new BadRequestException({
        code: ErrorCode.UPLOAD_FILE_TOO_LARGE,
        message: ErrorMessage[ErrorCode.UPLOAD_FILE_TOO_LARGE],
      });
    }
    return { url: `/uploads/${file.filename}` };
  }
}
