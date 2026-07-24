import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { PinoLogger } from 'nestjs-pino';
import { ReviewEntity, OrderEntity, OrderItemEntity, UserEntity } from '../../entities';
import { ErrorCode, ErrorMessage, OrderStatus } from 'shared';
import { CreateReviewDto } from './dto/create-review.dto';
import { QueryReviewDto } from './dto/query-review.dto';

@Injectable()
export class ReviewService {
  constructor(
    @InjectRepository(ReviewEntity)
    private readonly reviewRepo: Repository<ReviewEntity>,
    @InjectRepository(OrderEntity)
    private readonly orderRepo: Repository<OrderEntity>,
    @InjectRepository(OrderItemEntity)
    private readonly orderItemRepo: Repository<OrderItemEntity>,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    private readonly dataSource: DataSource,
    private readonly logger: PinoLogger,
  ) {
    this.logger.setContext(ReviewService.name);
  }

  /**
   * 商品评价列表（@Public），含评价者昵称/头像
   */
  async findByProduct(productId: number, query: QueryReviewDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 10;

    const qb = this.reviewRepo
      .createQueryBuilder('r')
      .leftJoin(UserEntity, 'u', 'u.id = r.userId')
      .addSelect(['u.nickname AS userNickname', 'u.avatar AS userAvatar'])
      .where('r.productId = :productId', { productId })
      .orderBy('r.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit);

    const { entities, raw } = await qb.getRawAndEntities();
    const total = await qb.getCount();
    const rawRows = raw as any[];

    const items = entities.map((entity, idx) => ({
      id: entity.id,
      productId: entity.productId,
      userId: entity.userId,
      orderId: entity.orderId,
      rating: entity.rating,
      content: entity.content,
      images: entity.images,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      userNickname: rawRows[idx]?.userNickname ?? null,
      userAvatar: rawRows[idx]?.userAvatar ?? null,
    }));

    return { list: items, total, page, limit };
  }

  /**
   * 我的评价
   */
  async findMine(userId: number, query: QueryReviewDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 10;

    const [list, total] = await this.reviewRepo.findAndCount({
      where: { userId },
      order: { createdAt: 'DESC' },
      skip: (page - 1) * limit,
      take: limit,
    });

    return { list, total, page, limit };
  }

  /**
   * 基于订单批量创建评价
   * 资格：订单 status === COMPLETED + 归属用户 + (orderId, productId) 未重复
   */
  async createFromOrder(userId: number, orderId: number, dto: CreateReviewDto) {
    // 1. 校验订单归属 + 状态
    const order = await this.orderRepo.findOne({
      where: { id: orderId, userId },
    });
    if (!order) {
      throw new NotFoundException(ErrorMessage[ErrorCode.ORDER_NOT_FOUND]);
    }
    if (order.status !== OrderStatus.COMPLETED) {
      throw new BadRequestException({
        code: ErrorCode.REVIEW_NOT_ALLOWED,
        message: ErrorMessage[ErrorCode.REVIEW_NOT_ALLOWED],
      });
    }

    // 2. 校验订单项匹配 + 未重复评价
    const orderItems = await this.orderItemRepo.find({
      where: { orderId },
    });
    const orderedProductIds = new Set(orderItems.map((i) => i.productId));
    const reviewProductIds = dto.reviews.map((r) => r.productId);

    // 所有评价商品都必须出现在订单中
    for (const pid of reviewProductIds) {
      if (!orderedProductIds.has(pid)) {
        throw new BadRequestException({
          code: ErrorCode.REVIEW_NOT_ALLOWED,
          message: ErrorMessage[ErrorCode.REVIEW_NOT_ALLOWED],
        });
      }
    }

    // 查重
    const existing = await this.reviewRepo.find({
      where: { orderId },
    });
    const existingSet = new Set(existing.map((r) => r.productId));
    for (const pid of reviewProductIds) {
      if (existingSet.has(pid)) {
        throw new BadRequestException({
          code: ErrorCode.REVIEW_EXISTS,
          message: ErrorMessage[ErrorCode.REVIEW_EXISTS],
        });
      }
    }

    // 3. 事务内批量创建
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      const entities = dto.reviews.map((item) =>
        queryRunner.manager.create(ReviewEntity, {
          productId: item.productId,
          userId,
          orderId,
          rating: item.rating,
          content: item.content,
          images: item.images ?? null,
        }),
      );
      const saved = await queryRunner.manager.save(ReviewEntity, entities);

      await queryRunner.commitTransaction();
      this.logger.info({ orderId, userId, count: saved.length }, '评价创建成功');
      return { created: saved.length, reviews: saved };
    } catch (err) {
      await queryRunner.rollbackTransaction();
      // 唯一约束兜底（并发场景）
      throw err;
    } finally {
      await queryRunner.release();
    }
  }
}
