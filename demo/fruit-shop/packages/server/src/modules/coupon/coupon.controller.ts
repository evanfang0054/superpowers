import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  ParseIntPipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from 'shared';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { CouponService } from './coupon.service';
import { CreateCouponTemplateDto, UpdateCouponTemplateDto } from './dto/create-coupon-template.dto';
import { CouponPreviewDto } from './dto/coupon-preview.dto';

@Controller()
@UseGuards(JwtAuthGuard)
export class CouponController {
  constructor(private readonly couponService: CouponService) {}

  // ===== 用户端 =====
  @Get('coupons/available')
  findAvailable(@CurrentUser('id') userId: number) {
    return this.couponService.findAvailable(userId);
  }

  @Get('coupons/mine')
  findMine(
    @CurrentUser('id') userId: number,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.couponService.findMine(userId, page ? Number(page) : 1, limit ? Number(limit) : 10);
  }

  @Post('coupons/:id/claim')
  claim(@CurrentUser('id') userId: number, @Param('id', ParseIntPipe) id: number) {
    return this.couponService.claim(userId, id);
  }

  @Post('coupons/preview')
  preview(@CurrentUser('id') userId: number, @Body() dto: CouponPreviewDto) {
    return this.couponService.preview(userId, dto);
  }

  // ===== Admin =====
  @Get('admin/coupons')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  findAllTemplates() {
    return this.couponService.findAllTemplates();
  }

  @Post('admin/coupons')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  createTemplate(@Body() dto: CreateCouponTemplateDto) {
    return this.couponService.createTemplate(dto);
  }

  @Put('admin/coupons/:id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  updateTemplate(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateCouponTemplateDto) {
    return this.couponService.updateTemplate(id, dto);
  }

  @Delete('admin/coupons/:id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  removeTemplate(@Param('id', ParseIntPipe) id: number) {
    return this.couponService.removeTemplate(id);
  }
}
