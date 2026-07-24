import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ProductEntity, CategoryEntity, OrderItemEntity } from '../../entities';
import { ProductService } from './product.service';
import { ProductController } from './product.controller';
import { CategoryController } from './category.controller';

@Module({
  imports: [TypeOrmModule.forFeature([ProductEntity, CategoryEntity, OrderItemEntity])],
  controllers: [ProductController, CategoryController],
  providers: [ProductService],
  exports: [ProductService],
})
export class ProductModule {}
