import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { OrderEntity, OrderItemEntity, ShippingEntity, RefundEntity } from '../../entities';
import { ShipDto } from './dto/ship.dto';
import { RefundRequestDto } from './dto/refund-request.dto';
import { OrderStatus, ErrorCode, ErrorMessage, RefundStatus } from 'shared';
import { PinoLogger } from 'nestjs-pino';

@Injectable()
export class OrderLifecycleService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly logger: PinoLogger,
  ) {
    this.logger.setContext(OrderLifecycleService.name);
  }

  /** 取消订单 */
  async cancel(userId: number, id: number, findOne: (uid: number, oid: number) => Promise<any>) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const rows: { id: number; status: number }[] = await queryRunner.manager.query(
        'SELECT id, status FROM orders WHERE id = ? AND user_id = ? FOR UPDATE',
        [id, userId],
      );
      if (rows.length === 0) {
        throw new NotFoundException({
          code: ErrorCode.ORDER_NOT_FOUND,
          message: ErrorMessage[ErrorCode.ORDER_NOT_FOUND],
        });
      }
      if (rows[0].status !== OrderStatus.PENDING) {
        throw new BadRequestException({
          code: ErrorCode.ORDER_CANCEL_NOT_ALLOWED,
          message: ErrorMessage[ErrorCode.ORDER_CANCEL_NOT_ALLOWED],
        });
      }
      const items = await queryRunner.manager.find(OrderItemEntity, {
        where: { orderId: id },
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
      await queryRunner.manager.query('UPDATE orders SET status = ? WHERE id = ?', [
        OrderStatus.CANCELLED,
        id,
      ]);
      const couponRows: { coupon_id: number | null }[] = await queryRunner.manager.query(
        'SELECT coupon_id FROM orders WHERE id = ?',
        [id],
      );
      const cid = couponRows[0]?.coupon_id;
      if (cid) {
        await queryRunner.manager.query(
          'UPDATE user_coupons SET order_id = NULL, used_at = NULL WHERE coupon_id = ? AND order_id = ?',
          [cid, id],
        );
      }
      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
    return findOne(userId, id);
  }

  /** 支付 */
  async pay(userId: number, id: number, findOne: (uid: number, oid: number) => Promise<any>) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      const rows: { id: number; status: number }[] = await queryRunner.manager.query(
        'SELECT id, status FROM orders WHERE id = ? AND user_id = ? FOR UPDATE',
        [id, userId],
      );
      if (rows.length === 0) {
        throw new NotFoundException({
          code: ErrorCode.ORDER_NOT_FOUND,
          message: ErrorMessage[ErrorCode.ORDER_NOT_FOUND],
        });
      }
      if (rows[0].status !== OrderStatus.PENDING) {
        throw new BadRequestException({
          code: ErrorCode.ORDER_STATUS_ERROR,
          message: ErrorMessage[ErrorCode.ORDER_STATUS_ERROR],
        });
      }
      await queryRunner.manager.query(
        'UPDATE orders SET status = ?, paid_at = NOW() WHERE id = ?',
        [OrderStatus.PAID, id],
      );
      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
    return findOne(userId, id);
  }

  /** 发货 (Admin) */
  async ship(id: number, dto: ShipDto, findOne: (oid: number) => Promise<any>) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      const rows: { id: number; status: number }[] = await queryRunner.manager.query(
        'SELECT id, status FROM orders WHERE id = ? FOR UPDATE',
        [id],
      );
      if (rows.length === 0) {
        throw new NotFoundException({
          code: ErrorCode.ORDER_NOT_FOUND,
          message: ErrorMessage[ErrorCode.ORDER_NOT_FOUND],
        });
      }
      if (rows[0].status !== OrderStatus.PAID) {
        throw new BadRequestException({
          code: ErrorCode.ORDER_STATUS_ERROR,
          message: ErrorMessage[ErrorCode.ORDER_STATUS_ERROR],
        });
      }
      const shipping = queryRunner.manager.create(ShippingEntity, {
        orderId: id,
        company: dto.company,
        trackingNo: dto.trackingNo,
        shippedAt: new Date(),
        status: 0,
      });
      await queryRunner.manager.save(ShippingEntity, shipping);
      await queryRunner.manager.query(
        'UPDATE orders SET status = ?, shipped_at = NOW() WHERE id = ?',
        [OrderStatus.SHIPPED, id],
      );
      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
    return findOne(id);
  }

  /** 确认收货 */
  async confirm(userId: number, id: number, findOne: (uid: number, oid: number) => Promise<any>) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      const rows: { id: number; status: number }[] = await queryRunner.manager.query(
        'SELECT id, status FROM orders WHERE id = ? AND user_id = ? FOR UPDATE',
        [id, userId],
      );
      if (rows.length === 0) {
        throw new NotFoundException({
          code: ErrorCode.ORDER_NOT_FOUND,
          message: ErrorMessage[ErrorCode.ORDER_NOT_FOUND],
        });
      }
      if (rows[0].status !== OrderStatus.SHIPPED) {
        throw new BadRequestException({
          code: ErrorCode.ORDER_STATUS_ERROR,
          message: ErrorMessage[ErrorCode.ORDER_STATUS_ERROR],
        });
      }
      await queryRunner.manager.query('UPDATE orders SET status = ? WHERE id = ?', [
        OrderStatus.COMPLETED,
        id,
      ]);
      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
    return findOne(userId, id);
  }

  /** 申请退款 */
  async requestRefund(
    userId: number,
    id: number,
    dto: RefundRequestDto,
    findOne: (uid: number, oid: number) => Promise<any>,
  ) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      const rows: { id: number; status: number }[] = await queryRunner.manager.query(
        'SELECT id, status FROM orders WHERE id = ? AND user_id = ? FOR UPDATE',
        [id, userId],
      );
      if (rows.length === 0) {
        throw new NotFoundException({
          code: ErrorCode.ORDER_NOT_FOUND,
          message: ErrorMessage[ErrorCode.ORDER_NOT_FOUND],
        });
      }
      const currentStatus = rows[0].status;
      if (currentStatus !== OrderStatus.PAID && currentStatus !== OrderStatus.SHIPPED) {
        throw new BadRequestException({
          code: ErrorCode.REFUND_NOT_ALLOWED,
          message: ErrorMessage[ErrorCode.REFUND_NOT_ALLOWED],
        });
      }
      const refund = queryRunner.manager.create(RefundEntity, {
        orderId: id,
        userId,
        reason: dto.reason,
        prevStatus: currentStatus,
        status: RefundStatus.PENDING,
      });
      await queryRunner.manager.save(RefundEntity, refund);
      await queryRunner.manager.query('UPDATE orders SET status = ? WHERE id = ?', [
        OrderStatus.REFUNDING,
        id,
      ]);
      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
    return findOne(userId, id);
  }
}
