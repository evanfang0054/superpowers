import {
  Injectable,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import {
  OrderEntity,
  OrderItemEntity,
  CartEntity,
  AddressEntity,
  UserCouponEntity,
} from '../../entities';
import { CartService } from '../cart/cart.service';
import { CouponService } from '../coupon/coupon.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { OrderStatus, ErrorCode, ErrorMessage } from 'shared';
import { PinoLogger } from 'nestjs-pino';

@Injectable()
export class OrderCheckoutService {
  constructor(
    @InjectRepository(CartEntity)
    private readonly cartRepo: Repository<CartEntity>,
    @InjectRepository(AddressEntity)
    private readonly addressRepo: Repository<AddressEntity>,
    @InjectRepository(UserCouponEntity)
    private readonly userCouponRepo: Repository<UserCouponEntity>,
    private readonly cartService: CartService,
    private readonly couponService: CouponService,
    private readonly dataSource: DataSource,
    private readonly logger: PinoLogger,
  ) {
    this.logger.setContext(OrderCheckoutService.name);
  }

  async create(userId: number, dto: CreateOrderDto) {
    const cartItems = await this.cartRepo.find({
      where: { userId },
      relations: ['product'],
    });

    if (cartItems.length === 0) {
      throw new BadRequestException({
        code: ErrorCode.CART_EMPTY,
        message: ErrorMessage[ErrorCode.CART_EMPTY],
      });
    }

    let orderAddress = dto.address;
    let orderPhone = dto.phone;
    if (dto.addressId) {
      const address = await this.addressRepo.findOne({
        where: { id: dto.addressId, userId },
      });
      if (!address) {
        throw new BadRequestException({
          code: ErrorCode.ADDRESS_NOT_FOUND,
          message: ErrorMessage[ErrorCode.ADDRESS_NOT_FOUND],
        });
      }
      orderAddress = `${address.province}${address.city}${address.district}${address.detail}`;
      orderPhone = address.phone;
    }

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const productIds = cartItems.map((item) => item.productId);
      const lockedProducts: { id: number; stock: number; name: string }[] =
        await queryRunner.manager.query(
          'SELECT id, stock, name FROM products WHERE id IN (?) FOR UPDATE',
          [productIds],
        );
      const stockMap = new Map(lockedProducts.map((p) => [p.id, p]));

      for (const item of cartItems) {
        if (!item.product) continue;
        const latest = stockMap.get(item.productId);
        if (!latest || latest.stock < item.quantity) {
          throw new BadRequestException({
            code: ErrorCode.STOCK_INSUFFICIENT,
            message: ErrorMessage[ErrorCode.STOCK_INSUFFICIENT],
          });
        }
      }

      let totalAmount = 0;
      const orderItems: Partial<OrderItemEntity>[] = [];
      const item_product_category = new Map<number, number>();
      for (const item of cartItems) {
        if (!item.product) continue;
        const price = Number(item.product.price);
        totalAmount += price * item.quantity;
        item_product_category.set(item.productId, item.product.categoryId);
        orderItems.push({
          productId: item.productId,
          productName: item.product.name,
          specLabel: item.specLabel,
          price,
          quantity: item.quantity,
          image: item.product.image,
        });
      }

      for (const item of cartItems) {
        if (!item.product) continue;
        await queryRunner.manager.query(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [item.quantity, item.productId],
        );
      }

      let discountAmount = 0;
      let userCouponDbId: number | null = null;
      let couponTemplateId: number | null = null;
      if (dto.couponId) {
        const ucRows: {
          id: number; user_id: number; coupon_id: number; used_at: Date | null;
        }[] = await queryRunner.manager.query(
          'SELECT id, user_id, coupon_id, used_at FROM user_coupons WHERE id = ? FOR UPDATE',
          [dto.couponId],
        );
        if (ucRows.length === 0) {
          throw new BadRequestException({
            code: ErrorCode.COUPON_NOT_FOUND,
            message: ErrorMessage[ErrorCode.COUPON_NOT_FOUND],
          });
        }
        const uc = ucRows[0];
        if (uc.user_id !== userId) {
          throw new BadRequestException({
            code: ErrorCode.COUPON_NOT_APPLICABLE,
            message: ErrorMessage[ErrorCode.COUPON_NOT_APPLICABLE],
          });
        }
        if (uc.used_at !== null && uc.used_at !== undefined) {
          throw new BadRequestException({
            code: ErrorCode.COUPON_USED,
            message: ErrorMessage[ErrorCode.COUPON_USED],
          });
        }
        const template = await this.couponService.getTemplate(uc.coupon_id);
        discountAmount = this.couponService.calculateDiscount(template, orderItems.map((i) => ({
          productId: i.productId!,
          quantity: i.quantity!,
          price: Number(i.price),
          categoryId: item_product_category.get(i.productId!)!,
        })));
        if (totalAmount - discountAmount < 0) {
          throw new BadRequestException({
            code: ErrorCode.COUPON_NOT_APPLICABLE,
            message: ErrorMessage[ErrorCode.COUPON_NOT_APPLICABLE],
          });
        }
        userCouponDbId = uc.id;
        couponTemplateId = uc.coupon_id;
      }

      const finalTotalAmount = Math.round((totalAmount - discountAmount) * 100) / 100;

      const orderNo = `${Date.now()}${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
      const order = queryRunner.manager.create(OrderEntity, {
        orderNo,
        userId,
        totalAmount: finalTotalAmount,
        status: OrderStatus.PENDING,
        address: orderAddress,
        phone: orderPhone,
        remark: dto.remark,
        couponId: couponTemplateId,
        discountAmount,
      });
      const savedOrder = await queryRunner.manager.save(OrderEntity, order);

      const items = orderItems.map((item) =>
        queryRunner.manager.create(OrderItemEntity, {
          ...item,
          orderId: savedOrder.id,
        }),
      );
      await queryRunner.manager.save(OrderItemEntity, items);

      if (userCouponDbId) {
        await queryRunner.manager.query(
          'UPDATE user_coupons SET order_id = ?, used_at = NOW() WHERE id = ?',
          [savedOrder.id, userCouponDbId],
        );
      }

      await queryRunner.manager
        .createQueryBuilder()
        .delete()
        .from(CartEntity)
        .where('user_id = :userId', { userId })
        .andWhere('product_id IN (:...productIds)', { productIds })
        .execute();

      await queryRunner.commitTransaction();

      this.logger.info(
        { orderId: savedOrder.id, orderNo, userId, totalAmount: finalTotalAmount, itemCount: orderItems.length, couponId: couponTemplateId, discountAmount },
        '订单创建成功',
      );

      return savedOrder;
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }
}
