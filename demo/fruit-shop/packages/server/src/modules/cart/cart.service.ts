import { Injectable, NotFoundException, BadRequestException, Inject } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { CartEntity, ProductEntity } from '../../entities';
import { AddToCartDto } from './dto/add-to-cart.dto';
import { UpdateCartDto } from './dto/update-cart.dto';
import { ErrorCode, ErrorMessage } from 'shared';

@Injectable()
export class CartService {
  constructor(
    @InjectRepository(CartEntity)
    private readonly cartRepo: Repository<CartEntity>,
    @InjectRepository(ProductEntity)
    private readonly productRepo: Repository<ProductEntity>,
    private readonly dataSource: DataSource,
  ) {}

  async findAll(userId: number) {
    const items = await this.cartRepo.find({
      where: { userId },
      relations: ['product'],
      order: { createdAt: 'DESC' },
    });

    return items.map((item) => ({
      id: item.id,
      userId: item.userId,
      productId: item.productId,
      specLabel: item.specLabel,
      quantity: item.quantity,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      product: item.product
        ? {
            id: item.product.id,
            name: item.product.name,
            price: item.product.price,
            originalPrice: item.product.originalPrice,
            image: item.product.image,
            unit: item.product.unit,
            stock: item.product.stock,
            status: item.product.status,
            categoryId: item.product.categoryId,
          }
        : null,
    }));
  }

  async add(userId: number, dto: AddToCartDto) {
    const product = await this.productRepo.findOne({
      where: { id: dto.productId },
    });
    if (!product) {
      throw new NotFoundException(ErrorMessage[ErrorCode.PRODUCT_NOT_FOUND]);
    }

    if (product.stock <= 0) {
      throw new BadRequestException({
        code: ErrorCode.PRODUCT_OUT_OF_STOCK,
        message: ErrorMessage[ErrorCode.PRODUCT_OUT_OF_STOCK],
      });
    }

    const quantity = dto.quantity ?? 1;

    // Check if item already exists in cart
    const existing = await this.cartRepo.findOne({
      where: {
        userId,
        productId: dto.productId,
        specLabel: dto.specLabel,
      },
    });

    if (existing) {
      // Merge quantity
      existing.quantity += quantity;
      await this.cartRepo.save(existing);
    } else {
      // Insert new cart item
      const cartItem = this.cartRepo.create({
        userId,
        productId: dto.productId,
        specLabel: dto.specLabel,
        quantity,
      });
      await this.cartRepo.save(cartItem);
    }

    return this.findAll(userId);
  }

  async update(id: number, userId: number, dto: UpdateCartDto) {
    const item = await this.cartRepo.findOne({
      where: { id, userId },
    });
    if (!item) {
      throw new NotFoundException(ErrorMessage[ErrorCode.CART_ITEM_NOT_FOUND]);
    }

    item.quantity = dto.quantity;
    await this.cartRepo.save(item);
    return this.findAll(userId);
  }

  async remove(id: number, userId: number) {
    const item = await this.cartRepo.findOne({
      where: { id, userId },
    });
    if (!item) {
      throw new NotFoundException(ErrorMessage[ErrorCode.CART_ITEM_NOT_FOUND]);
    }

    await this.cartRepo.remove(item);
    return this.findAll(userId);
  }

  async clearByUser(userId: number) {
    await this.cartRepo
      .createQueryBuilder()
      .delete()
      .from(CartEntity)
      .where('user_id = :userId', { userId })
      .execute();
    return this.findAll(userId);
  }

  async removeByUserAndProductIds(userId: number, productIds: number[]): Promise<void> {
    if (productIds.length === 0) return;
    await this.cartRepo
      .createQueryBuilder()
      .delete()
      .from(CartEntity)
      .where('user_id = :userId', { userId })
      .andWhere('product_id IN (:...productIds)', { productIds })
      .execute();
  }
}
