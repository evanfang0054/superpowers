import { Injectable, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PinoLogger } from 'nestjs-pino';
import { FavoriteEntity, ProductEntity } from '../../entities';
import { ErrorCode, ErrorMessage } from 'shared';
import { QueryFavoriteDto } from './dto/query-favorite.dto';

@Injectable()
export class FavoriteService {
  constructor(
    @InjectRepository(FavoriteEntity)
    private readonly favoriteRepo: Repository<FavoriteEntity>,
    @InjectRepository(ProductEntity)
    private readonly productRepo: Repository<ProductEntity>,
    private readonly logger: PinoLogger,
  ) {
    this.logger.setContext(FavoriteService.name);
  }

  /**
   * 收藏商品，已收藏抛 FAVORITE_EXISTS(40801)
   */
  async add(userId: number, productId: number) {
    const existing = await this.favoriteRepo.findOne({
      where: { userId, productId },
    });
    if (existing) {
      throw new BadRequestException({
        code: ErrorCode.FAVORITE_EXISTS,
        message: ErrorMessage[ErrorCode.FAVORITE_EXISTS],
      });
    }

    const entity = this.favoriteRepo.create({ userId, productId });
    const saved = await this.favoriteRepo.save(entity);
    this.logger.info({ userId, productId, favoriteId: saved.id }, '收藏成功');
    return { id: saved.id, userId, productId, createdAt: saved.createdAt };
  }

  /**
   * 取消收藏，未收藏抛 FAVORITE_NOT_FOUND(40802)
   */
  async remove(userId: number, productId: number) {
    const existing = await this.favoriteRepo.findOne({
      where: { userId, productId },
    });
    if (!existing) {
      throw new BadRequestException({
        code: ErrorCode.FAVORITE_NOT_FOUND,
        message: ErrorMessage[ErrorCode.FAVORITE_NOT_FOUND],
      });
    }

    await this.favoriteRepo.remove(existing);
    this.logger.info({ userId, productId }, '取消收藏成功');
    return { id: existing.id, userId, productId };
  }

  /**
   * 我的收藏列表（分页 + 商品详情）
   */
  async findAll(userId: number, query: QueryFavoriteDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 10;

    const qb = this.favoriteRepo
      .createQueryBuilder('f')
      .leftJoinAndSelect(ProductEntity, 'p', 'p.id = f.productId')
      .where('f.userId = :userId', { userId })
      .orderBy('f.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit);

    const [favorites, total] = await qb.getManyAndCount();

    // 单独取商品信息（避免 join 后 entity 字段映射问题）
    const productIds = favorites.map((f) => f.productId);
    const products =
      productIds.length > 0
        ? await this.productRepo.find({
            where: productIds.map((id) => ({ id })),
          })
        : [];
    const productMap = new Map(products.map((p) => [p.id, p]));

    const list = favorites.map((f) => {
      const p = productMap.get(f.productId) ?? null;
      return {
        id: f.id,
        userId: f.userId,
        productId: f.productId,
        createdAt: f.createdAt,
        product: p
          ? {
              id: p.id,
              name: p.name,
              price: p.price,
              image: p.image,
              status: p.status,
            }
          : null,
      };
    });

    return { list, total, page, limit };
  }

  /**
   * 查询某商品是否已收藏
   */
  async getStatus(userId: number, productId: number) {
    const existing = await this.favoriteRepo.findOne({
      where: { userId, productId },
    });
    return { favorited: !!existing };
  }
}
