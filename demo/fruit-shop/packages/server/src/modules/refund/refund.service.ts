import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { PinoLogger } from 'nestjs-pino';
import { RefundEntity, OrderEntity, OrderItemEntity, ProductEntity } from '../../entities';
import { RefundReviewDto } from '../order/dto/refund-review.dto';
import { ErrorCode, ErrorMessage, OrderStatus, RefundStatus } from 'shared';

@Injectable()
export class RefundService {
  constructor(
    @InjectRepository(RefundEntity)
    private readonly refundRepo: Repository<RefundEntity>,
    private readonly dataSource: DataSource,
    private readonly logger: PinoLogger,
  ) {
    this.logger.setContext(RefundService.name);
  }

  async findAll(query: { page?: number; limit?: number; status?: number }) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 10;
    const qb = this.refundRepo.createQueryBuilder('r');
    if (query.status !== undefined) {
      qb.andWhere('r.status = :status', { status: query.status });
    }
    qb.orderBy('r.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit);
    const [list, total] = await qb.getManyAndCount();
    return { list, total, page, limit };
  }

  async approve(refundId: number) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      // 1. 锁 refund 行
      const refundRows: {
        id: number;
        status: number;
        order_id: number;
        prev_status: number;
      }[] = await queryRunner.manager.query(
        'SELECT id, status, order_id, prev_status FROM refunds WHERE id = ? FOR UPDATE',
        [refundId],
      );
      if (refundRows.length === 0) {
        throw new NotFoundException(ErrorMessage[ErrorCode.REFUND_NOT_FOUND]);
      }
      const refundRow = refundRows[0];
      if (refundRow.status !== RefundStatus.PENDING) {
        throw new BadRequestException({
          code: ErrorCode.ORDER_STATUS_ERROR,
          message: ErrorMessage[ErrorCode.ORDER_STATUS_ERROR],
        });
      }
      const orderId = refundRow.order_id;

      // 2. 锁 order 行
      await queryRunner.manager.query('SELECT id FROM orders WHERE id = ? FOR UPDATE', [orderId]);

      // 3. 锁相关商品 + 回补库存
      const items = await queryRunner.manager.find(OrderItemEntity, {
        where: { orderId },
      });
      const productIds = items.map((i) => i.productId);
      if (productIds.length > 0) {
        await queryRunner.manager.query('SELECT id FROM products WHERE id IN (?) FOR UPDATE', [
          productIds,
        ]);
        for (const item of items) {
          await queryRunner.manager.query('UPDATE products SET stock = stock + ? WHERE id = ?', [
            item.quantity,
            item.productId,
          ]);
        }
      }

      // 4. 解绑优惠券（若有）
      const orderRows: { coupon_id: number | null }[] = await queryRunner.manager.query(
        'SELECT coupon_id FROM orders WHERE id = ?',
        [orderId],
      );
      const couponId = orderRows[0]?.coupon_id;
      if (couponId) {
        await queryRunner.manager.query(
          'UPDATE user_coupons SET order_id = NULL, used_at = NULL WHERE coupon_id = ? AND order_id = ?',
          [couponId, orderId],
        );
      }

      // 5. 更新状态
      await queryRunner.manager.query('UPDATE orders SET status = ? WHERE id = ?', [
        OrderStatus.REFUNDED,
        orderId,
      ]);
      await queryRunner.manager.query('UPDATE refunds SET status = ? WHERE id = ?', [
        RefundStatus.APPROVED,
        refundId,
      ]);

      await queryRunner.commitTransaction();
      this.logger.info({ refundId, orderId }, '退款通过，库存回补 + 券解绑');
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
    return this.refundRepo.findOne({ where: { id: refundId } });
  }

  async reject(refundId: number, dto: RefundReviewDto) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      const refundRows: {
        id: number;
        status: number;
        order_id: number;
        prev_status: number;
      }[] = await queryRunner.manager.query(
        'SELECT id, status, order_id, prev_status FROM refunds WHERE id = ? FOR UPDATE',
        [refundId],
      );
      if (refundRows.length === 0) {
        throw new NotFoundException(ErrorMessage[ErrorCode.REFUND_NOT_FOUND]);
      }
      const refundRow = refundRows[0];
      if (refundRow.status !== RefundStatus.PENDING) {
        throw new BadRequestException({
          code: ErrorCode.ORDER_STATUS_ERROR,
          message: ErrorMessage[ErrorCode.ORDER_STATUS_ERROR],
        });
      }

      // 恢复 prevStatus
      await queryRunner.manager.query('UPDATE orders SET status = ? WHERE id = ?', [
        refundRow.prev_status,
        refundRow.order_id,
      ]);
      await queryRunner.manager.query(
        'UPDATE refunds SET status = ?, admin_note = ? WHERE id = ?',
        [RefundStatus.REJECTED, dto.adminNote ?? null, refundId],
      );

      await queryRunner.commitTransaction();
      this.logger.info(
        { refundId, restoredStatus: refundRow.prev_status },
        '退款拒绝，恢复订单状态',
      );
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
    return this.refundRepo.findOne({ where: { id: refundId } });
  }
}
