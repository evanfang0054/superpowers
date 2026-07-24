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
import { OrderLifecycleService } from './order-lifecycle.service';

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
    private readonly lifecycleService: OrderLifecycleService,
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

  /** 取消订单 */
  async cancel(userId: number, id: number) {
    return this.lifecycleService.cancel(userId, id, (uid, oid) =>
      this.findOne(uid, oid),
    );
  }

  /** 支付 */
  async pay(userId: number, id: number) {
    return this.lifecycleService.pay(userId, id, (uid, oid) =>
      this.findOne(uid, oid),
    );
  }

  /** 发货 (Admin) */
  async ship(id: number, dto: ShipDto) {
    return this.lifecycleService.ship(id, dto, (oid) =>
      this.findOneInternal(oid),
    );
  }

  /** 确认收货 */
  async confirm(userId: number, id: number) {
    return this.lifecycleService.confirm(userId, id, (uid, oid) =>
      this.findOne(uid, oid),
    );
  }

  /** 申请退款 */
  async requestRefund(userId: number, id: number, dto: RefundRequestDto) {
    return this.lifecycleService.requestRefund(
      userId,
      id,
      dto,
      (uid, oid) => this.findOne(uid, oid),
    );
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
