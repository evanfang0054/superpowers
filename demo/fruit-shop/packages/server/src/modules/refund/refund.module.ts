import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RefundEntity, OrderEntity, OrderItemEntity, ProductEntity } from '../../entities';
import { RefundService } from './refund.service';
import { RefundController } from './refund.controller';

@Module({
  imports: [TypeOrmModule.forFeature([RefundEntity, OrderEntity, OrderItemEntity, ProductEntity])],
  controllers: [RefundController],
  providers: [RefundService],
})
export class RefundModule {}
