import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Query,
  UseGuards,
  ParseIntPipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { FavoriteService } from './favorite.service';
import { QueryFavoriteDto } from './dto/query-favorite.dto';

/**
 * 收藏模块跨多路径前缀（products/:id/favorite、products/:id/favorite-status、favorites），
 * 故用基础 @Controller() + 每个方法显式完整路径。
 */
@Controller()
@UseGuards(JwtAuthGuard)
export class FavoriteController {
  constructor(private readonly favoriteService: FavoriteService) {}

  // 收藏商品
  @Post('products/:id/favorite')
  add(@CurrentUser('id') userId: number, @Param('id', ParseIntPipe) id: number) {
    return this.favoriteService.add(userId, id);
  }

  // 取消收藏
  @Delete('products/:id/favorite')
  remove(@CurrentUser('id') userId: number, @Param('id', ParseIntPipe) id: number) {
    return this.favoriteService.remove(userId, id);
  }

  // 我的收藏列表（分页 + 商品详情）
  @Get('favorites')
  findAll(@CurrentUser('id') userId: number, @Query() query: QueryFavoriteDto) {
    return this.favoriteService.findAll(userId, query);
  }

  // 查询某商品是否已收藏
  @Get('products/:id/favorite-status')
  getStatus(@CurrentUser('id') userId: number, @Param('id', ParseIntPipe) id: number) {
    return this.favoriteService.getStatus(userId, id);
  }
}
