import { Controller, Get, Post, Param, Body, Query, UseGuards, ParseIntPipe } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ReviewService } from './review.service';
import { CreateReviewDto } from './dto/create-review.dto';
import { QueryReviewDto } from './dto/query-review.dto';

/**
 * 评价模块跨多路径前缀（products/:id/reviews、orders/:id/reviews、reviews/mine），
 * 故用基础 @Controller() + 每个方法显式完整路径。
 */
@Controller()
@UseGuards(JwtAuthGuard)
export class ReviewController {
  constructor(private readonly reviewService: ReviewService) {}

  // 商品评价列表（公开）
  @Public()
  @Get('products/:id/reviews')
  findByProduct(@Param('id', ParseIntPipe) id: number, @Query() query: QueryReviewDto) {
    return this.reviewService.findByProduct(id, query);
  }

  // 基于订单批量创建评价（JWT）
  @Post('orders/:id/reviews')
  createFromOrder(
    @CurrentUser('id') userId: number,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CreateReviewDto,
  ) {
    return this.reviewService.createFromOrder(userId, id, dto);
  }

  // 我的评价（JWT）
  @Get('reviews/mine')
  findMine(@CurrentUser('id') userId: number, @Query() query: QueryReviewDto) {
    return this.reviewService.findMine(userId, query);
  }
}
