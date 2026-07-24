import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import {
  OrderEntity,
  OrderItemEntity,
  ShippingEntity,
  RefundEntity,
  AddressEntity,
} from '../../entities';
import { QueryOrderDto } from './dto/query-order.dto';
import { ShipDto } from './dto/ship.dto';
import { RefundRequestDto } from './dto/refund-request.dto';
import { RefundReviewDto } from './dto/refund-review.dto';
import { OrderStatus, ErrorCode, ErrorMessage, RefundStatus } from 'shared';
import { PinoLogger } from 'nestjs-pino';
import { OrderCheckoutService } from './order-checkout.service';

@Injectable()
export class OrderService {
  constructor(
    @InjectRepository(OrderEntity)
    private readonly orderRepo: Repository<OrderEntity>,
    @InjectRepository(OrderItemEntity)
    private readonly orderItemRepo: Repository<OrderItemEntity>,
    @InjectRepository(ShippingEntity)
    private readonly shippingRepo: Repository<ShippingEntity>,
    @InjectRepository(RefundEntity)
    private readonly refundRepo: Repository<RefundEntity>,
    @InjectRepository(AddressEntity)
    private readonly addressRepo: Repository<AddressEntity>,
    private readonly checkoutService: OrderCheckoutService,
    private readonly dataSource: DataSource,
    private readonly logger: PinoLogger,
  ) {
    this.logger.setContext(OrderService.name);
  }

  /** 下单 → 委托给 CheckoutService */
  async create(userId: number, dto: import('./dto/create-order.dto').CreateOrderDto) {
    const savedOrder = await this.checkoutService.create(userId, dto);
    return this.findOne(userId, savedOrder.id);
  }

  /** 订单列表 */
  async findAll(userId: number, query: QueryOrderDto) {
    const { status, page = 1, limit = 10 } = query;
    const qb = this.orderRepo
      .createQueryBuilder('o')
      .where('o.user_id = :userId', { userId });
    if (status !== undefined) {
      qb.andWhere('o.status = :status', { status });
    }
    const total = await qb.getCount();
    const list = await qb
      .orderBy('o.created_at', 'DESC')
      .skip((page - 1) * limit)
      .take(limit)
      .getMany();
    return { list, total, page, limit };
  }

  /** 订单详情 */
  async findOne(userId: number, id: number) {
    const order = await this.orderRepo.findOne({ where: { id, userId } });
    if (!order) {
      throw new NotFoundException({
        code: ErrorCode.ORDER_NOT_FOUND,
        message: ErrorMessage[ErrorCode.ORDER_NOT_FOUND],
      });
    }
    const items = await this.orderItemRepo.find({ where: { orderId: id } });
    return { ...order, items };
  }

  // ─── Lifecycle methods (to be extracted to OrderLifecycleService in Task 5) ───

  /** 取消订单 */
  async cancel(userId: number, id: number) {
    // TODO(Task 5): delegate to OrderLifecycleService.cancel()
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // 1. 行锁 + 归属校验（一并完成）
      const rows: { id: number; status: number }[] =
        await queryRunner.manager.query(
          'SELECT id, status FROM orders WHERE id = ? AND user_id = ? FOR UPDATE',
          [id, userId],
        );
      if (rows.length === 0) {
        throw new NotFoundException({
        code: ErrorCode.ORDER_NOT_FOUND,
        message: ErrorMessage[ErrorCode.ORDER_NOT_FOUND],
      });
      }
      // 2. 状态校验
      if (rows[0].status !== OrderStatus.PENDING) {
        throw new BadRequestException({
          code: ErrorCode.ORDER_CANCEL_NOT_ALLOWED,
          message: ErrorMessage[ErrorCode.ORDER_CANCEL_NOT_ALLOWED],
        });
      }

      // 3. 锁订单项对应商品 + 回补库存
      const items = await queryRunner.manager.find(OrderItemEntity, {
        where: { orderId: id },
      });
      const productIds = items.map((i) => i.productId);
      if (productIds.length > 0) {
        await queryRunner.manager.query(
          'SELECT id FROM products WHERE id IN (?) FOR UPDATE',
          [productIds],
        );
        for (const item of items) {
          await queryRunner.manager.query(
            'UPDATE products SET stock = stock + ? WHERE id = ?',
            [item.quantity, item.productId],
          );
        }
      }

      // 4. 改订单状态
      await queryRunner.manager.query(
        'UPDATE orders SET status = ? WHERE id = ?',
        [OrderStatus.CANCELLED, id],
      );

      // 4.5 解绑优惠券（若有）
      const couponRows: { coupon_id: number | null }[] =
        await queryRunner.manager.query(
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

    return this.findOne(userId, id);
  }

  /** 支付 */
  async pay(userId: number, id: number) {
    // TODO(Task 5): delegate to OrderLifecycleService.pay()
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      const rows: { id: number; status: number }[] =
        await queryRunner.manager.query(
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
    return this.findOne(userId, id);
  }

  /** 发货 (Admin) */
  async ship(id: number, dto: ShipDto) {
    // TODO(Task 5): delegate to OrderLifecycleService.ship()
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      const rows: { id: number; status: number }[] =
        await queryRunner.manager.query(
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
    return this.findOneInternal(id);
  }

  /** 确认收货 */
  async confirm(userId: number, id: number) {
    // TODO(Task 5): delegate to OrderLifecycleService.confirm()
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      const rows: { id: number; status: number }[] =
        await queryRunner.manager.query(
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
      await queryRunner.manager.query(
        'UPDATE orders SET status = ? WHERE id = ?',
        [OrderStatus.COMPLETED, id],
      );
      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
    return this.findOne(userId, id);
  }

  /** 申请退款 */
  async requestRefund(userId: number, id: number, dto: RefundRequestDto) {
    // TODO(Task 5): delegate to OrderLifecycleService.requestRefund()
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      const rows: { id: number; status: number }[] =
        await queryRunner.manager.query(
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
      if (
        currentStatus !== OrderStatus.PAID &&
        currentStatus !== OrderStatus.SHIPPED
      ) {
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
      await queryRunner.manager.query(
        'UPDATE orders SET status = ? WHERE id = ?',
        [OrderStatus.REFUNDING, id],
      );
      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
    return this.findOne(userId, id);
  }

  /** 物流信息 */
  async findShipping(id: number) {
    const order = await this.orderRepo.findOne({ where: { id } });
    if (!order) {
      throw new NotFoundException({
        code: ErrorCode.ORDER_NOT_FOUND,
        message: ErrorMessage[ErrorCode.ORDER_NOT_FOUND],
      });
    }
    const shipping = await this.shippingRepo.findOne({ where: { orderId: id } });
    return shipping;
  }

  /** 内部查询（不校验 userId）*/
  private async findOneInternal(id: number) {
    const order = await this.orderRepo.findOne({ where: { id } });
    if (!order) {
      throw new NotFoundException({
        code: ErrorCode.ORDER_NOT_FOUND,
        message: ErrorMessage[ErrorCode.ORDER_NOT_FOUND],
      });
    }
    const items = await this.orderItemRepo.find({ where: { orderId: id } });
    return { ...order, items };
  }
}
