import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { PinoLogger } from 'nestjs-pino';
import { CouponTemplateEntity, UserCouponEntity } from '../../entities';
import { CouponType, ErrorCode, ErrorMessage } from 'shared';
import { CreateCouponTemplateDto, UpdateCouponTemplateDto } from './dto/create-coupon-template.dto';
import { CouponPreviewDto } from './dto/coupon-preview.dto';

@Injectable()
export class CouponService {
  constructor(
    @InjectRepository(CouponTemplateEntity)
    private readonly templateRepo: Repository<CouponTemplateEntity>,
    @InjectRepository(UserCouponEntity)
    private readonly userCouponRepo: Repository<UserCouponEntity>,
    private readonly dataSource: DataSource,
    private readonly logger: PinoLogger,
  ) {
    this.logger.setContext(CouponService.name);
  }

  /**
   * 可领取优惠券列表：status=1 + 有效期内 + 未领完；附当前用户是否已领取标记
   */
  async findAvailable(userId: number) {
    const now = new Date();
    const templates = await this.templateRepo
      .createQueryBuilder('t')
      .where('t.status = :status', { status: 1 })
      .andWhere('t.start_at <= :now', { now })
      .andWhere('t.end_at >= :now', { now })
      .andWhere('t.claimed_count < t.total_count')
      .getMany();

    if (templates.length === 0) return [];

    const templateIds = templates.map((t) => t.id);
    const claimed = await this.userCouponRepo
      .createQueryBuilder('uc')
      .select(['uc.coupon_id AS couponId'])
      .where('uc.user_id = :userId', { userId })
      .andWhere('uc.coupon_id IN (:...templateIds)', { templateIds })
      .andWhere('uc.used_at IS NULL')
      .getRawMany();
    const claimedSet = new Set(claimed.map((c) => Number(c.couponId)));

    return templates.map((t) => ({
      ...t,
      claimed: claimedSet.has(t.id),
    }));
  }

  /**
   * 我的优惠券（未使用的）
   */
  async findMine(userId: number, page = 1, limit = 10) {
    const [list, total] = await this.userCouponRepo.findAndCount({
      where: { userId, usedAt: null as any },
      order: { createdAt: 'DESC' },
      skip: (page - 1) * limit,
      take: limit,
    });

    if (list.length === 0) {
      return { list: [], total, page, limit };
    }

    const couponIds = Array.from(new Set(list.map((uc) => uc.couponId)));
    const templates = await this.templateRepo
      .createQueryBuilder('t')
      .where('t.id IN (:...couponIds)', { couponIds })
      .getMany();
    const templateMap = new Map(templates.map((t) => [t.id, t]));

    return {
      list: list.map((uc) => ({
        ...uc,
        coupon: templateMap.get(uc.couponId) ?? null,
      })),
      total,
      page,
      limit,
    };
  }

  /**
   * 领取优惠券（事务 + FOR UPDATE）
   */
  async claim(userId: number, couponId: number) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      const rows: {
        id: number;
        status: number;
        start_at: Date;
        end_at: Date;
        total_count: number;
        claimed_count: number;
      }[] = await queryRunner.manager.query(
        'SELECT id, status, start_at, end_at, total_count, claimed_count FROM coupon_templates WHERE id = ? FOR UPDATE',
        [couponId],
      );
      if (rows.length === 0) {
        throw new NotFoundException({
          code: ErrorCode.COUPON_NOT_FOUND,
          message: ErrorMessage[ErrorCode.COUPON_NOT_FOUND],
        });
      }
      const t = rows[0];
      if (t.status !== 1) {
        throw new BadRequestException({
          code: ErrorCode.COUPON_NOT_APPLICABLE,
          message: ErrorMessage[ErrorCode.COUPON_NOT_APPLICABLE],
        });
      }
      const now = new Date();
      if (now < new Date(t.start_at) || now > new Date(t.end_at)) {
        throw new BadRequestException({
          code: ErrorCode.COUPON_EXPIRED,
          message: ErrorMessage[ErrorCode.COUPON_EXPIRED],
        });
      }
      if (t.claimed_count >= t.total_count) {
        throw new BadRequestException({
          code: ErrorCode.COUPON_SOLD_OUT,
          message: ErrorMessage[ErrorCode.COUPON_SOLD_OUT],
        });
      }

      await queryRunner.manager.query(
        'UPDATE coupon_templates SET claimed_count = claimed_count + 1 WHERE id = ?',
        [couponId],
      );
      const uc = queryRunner.manager.create(UserCouponEntity, {
        userId,
        couponId,
        orderId: null,
        usedAt: null,
      });
      const saved = await queryRunner.manager.save(UserCouponEntity, uc);

      await queryRunner.commitTransaction();
      return saved;
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }

  /**
   * 折扣计算（核心逻辑）：根据 template.type 计算 discountAmount
   * @param items { productId, quantity, price, categoryId }[]
   * @throws BadRequestException(COUPON_MIN_NOT_MET / COUPON_NOT_APPLICABLE)
   */
  calculateDiscount(
    template: CouponTemplateEntity,
    items: Array<{
      productId: number;
      quantity: number;
      price: number;
      categoryId: number;
    }>,
  ): number {
    const minAmount = Number(template.minAmount) || 0;
    const applicableItems = template.categoryId
      ? items.filter((i) => i.categoryId === template.categoryId)
      : items;
    const subtotal = applicableItems.reduce((sum, i) => sum + Number(i.price) * i.quantity, 0);

    // 计算门槛时按应用范围的小计计算
    if (subtotal < minAmount) {
      throw new BadRequestException({
        code: ErrorCode.COUPON_MIN_NOT_MET,
        message: ErrorMessage[ErrorCode.COUPON_MIN_NOT_MET],
      });
    }

    let discount = 0;
    if (template.type === CouponType.FULL_REDUCTION) {
      discount = Number(template.discountAmount) || 0;
    } else if (template.type === CouponType.DISCOUNT) {
      const rate = Number(template.discountRate);
      if (!rate || rate <= 0 || rate > 1) {
        throw new BadRequestException({
          code: ErrorCode.COUPON_NOT_APPLICABLE,
          message: ErrorMessage[ErrorCode.COUPON_NOT_APPLICABLE],
        });
      }
      discount = Math.round(subtotal * (1 - rate) * 100) / 100;
    } else if (template.type === CouponType.NO_THRESHOLD) {
      discount = Number(template.discountAmount) || 0;
    } else {
      throw new BadRequestException({
        code: ErrorCode.COUPON_NOT_APPLICABLE,
        message: ErrorMessage[ErrorCode.COUPON_NOT_APPLICABLE],
      });
    }

    // 折扣不应超过小计
    if (discount > subtotal) discount = subtotal;
    if (discount < 0) discount = 0;
    return Math.round(discount * 100) / 100;
  }

  /**
   * 预览折扣
   */
  async preview(userId: number, dto: CouponPreviewDto) {
    const template = await this.templateRepo.findOne({
      where: { id: dto.couponId },
    });
    if (!template) {
      throw new NotFoundException({
        code: ErrorCode.COUPON_NOT_FOUND,
        message: ErrorMessage[ErrorCode.COUPON_NOT_FOUND],
      });
    }

    const discountAmount = this.calculateDiscount(template, dto.items);
    const totalBefore = dto.items.reduce((s, i) => s + Number(i.price) * i.quantity, 0);
    const totalAfterDiscount = Math.max(0, Math.round((totalBefore - discountAmount) * 100) / 100);

    return {
      discountAmount,
      totalAfterDiscount: totalAfterDiscount,
    };
  }

  /**
   * OrderService 调用：在订单事务内根据 userCouponId 计算折扣
   * 返回 { template, discountAmount }
   */
  async getTemplate(couponId: number): Promise<CouponTemplateEntity> {
    const template = await this.templateRepo.findOne({
      where: { id: couponId },
    });
    if (!template) {
      throw new NotFoundException({
        code: ErrorCode.COUPON_NOT_FOUND,
        message: ErrorMessage[ErrorCode.COUPON_NOT_FOUND],
      });
    }
    return template;
  }

  // ===== Admin CRUD =====
  async findAllTemplates() {
    return this.templateRepo.find({ order: { createdAt: 'DESC' } });
  }

  async createTemplate(dto: CreateCouponTemplateDto) {
    const template = this.templateRepo.create({
      name: dto.name,
      type: dto.type,
      minAmount: dto.minAmount ?? 0,
      discountAmount: dto.discountAmount ?? 0,
      discountRate: dto.discountRate ?? null,
      categoryId: dto.categoryId ?? null,
      totalCount: dto.totalCount ?? 0,
      startAt: new Date(dto.startAt),
      endAt: new Date(dto.endAt),
      status: dto.status ?? 1,
      claimedCount: 0,
    });
    return this.templateRepo.save(template);
  }

  async updateTemplate(id: number, dto: UpdateCouponTemplateDto) {
    const template = await this.templateRepo.findOne({ where: { id } });
    if (!template) {
      throw new NotFoundException({
        code: ErrorCode.COUPON_NOT_FOUND,
        message: ErrorMessage[ErrorCode.COUPON_NOT_FOUND],
      });
    }
    Object.assign(template, {
      ...dto,
      startAt: dto.startAt ? new Date(dto.startAt) : template.startAt,
      endAt: dto.endAt ? new Date(dto.endAt) : template.endAt,
    });
    return this.templateRepo.save(template);
  }

  async removeTemplate(id: number) {
    const template = await this.templateRepo.findOne({ where: { id } });
    if (!template) {
      throw new NotFoundException({
        code: ErrorCode.COUPON_NOT_FOUND,
        message: ErrorMessage[ErrorCode.COUPON_NOT_FOUND],
      });
    }
    await this.templateRepo.remove(template);
    return { id };
  }
}
