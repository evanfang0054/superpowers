import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  OrderEntity,
  OrderItemEntity,
  CartEntity,
  ShippingEntity,
  RefundEntity,
  AddressEntity,
  UserCouponEntity,
  CouponTemplateEntity,
} from '../../entities';
import { CartModule } from '../cart/cart.module';
import { CouponModule } from '../coupon/coupon.module';
import { OrderService } from './order.service';
import { OrderCheckoutService } from './order-checkout.service';
import { OrderLifecycleService } from './order-lifecycle.service';
import { OrderController } from './order.controller';

@Module({
  imports: [
    CartModule,
    CouponModule,
    TypeOrmModule.forFeature([
      OrderEntity,
      OrderItemEntity,
      CartEntity,
      ShippingEntity,
      RefundEntity,
      AddressEntity,
      UserCouponEntity,
      CouponTemplateEntity,
    ]),
  ],
  controllers: [OrderController],
  providers: [OrderService, OrderCheckoutService, OrderLifecycleService],
  exports: [OrderService],
})
export class OrderModule {}
