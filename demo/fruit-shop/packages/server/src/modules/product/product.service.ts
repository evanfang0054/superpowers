import { Injectable, NotFoundException, BadRequestException, Inject } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like } from 'typeorm';
import { Redis } from 'ioredis';
import { ProductEntity, CategoryEntity, OrderItemEntity } from '../../entities';
import { QueryProductDto, ProductSortBy } from './dto/query-product.dto';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { ErrorCode, ErrorMessage, ProductStatus } from 'shared';

@Injectable()
export class ProductService {
  constructor(
    @InjectRepository(ProductEntity)
    private readonly productRepo: Repository<ProductEntity>,
    @InjectRepository(CategoryEntity)
    private readonly categoryRepo: Repository<CategoryEntity>,
    @InjectRepository(OrderItemEntity)
    private readonly orderItemRepo: Repository<OrderItemEntity>,
    @Inject('REDIS_CLIENT')
    private readonly redis: Redis,
  ) {}

  async findAll(query: QueryProductDto) {
    const {
      categoryId,
      keyword,
      page = 1,
      limit = 10,
      minPrice,
      maxPrice,
      origin,
      sortBy = 'created_desc',
    } = query;
    const cacheKey = `products:${categoryId || 'all'}:${keyword || 'all'}:${page}:${limit}:${minPrice ?? 'all'}:${maxPrice ?? 'all'}:${origin || 'all'}:${sortBy}`;

    // Try cache first
    const cached = await this.redis.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }

    const qb = this.productRepo.createQueryBuilder('p');

    if (categoryId) {
      qb.andWhere('p.category_id = :categoryId', { categoryId });
    }

    if (keyword) {
      qb.andWhere('p.name LIKE :keyword', { keyword: `%${keyword}%` });
    }

    if (minPrice !== undefined) {
      qb.andWhere('p.price >= :minPrice', { minPrice });
    }
    if (maxPrice !== undefined) {
      qb.andWhere('p.price <= :maxPrice', { maxPrice });
    }
    if (origin) {
      qb.andWhere('p.origin = :origin', { origin });
    }

    qb.andWhere('p.status = :status', { status: ProductStatus.ON });

    this.applySort(qb, sortBy);

    const total = await qb.getCount();
    const list = await qb
      .skip((page - 1) * limit)
      .take(limit)
      .getMany();

    const result = { list, total, page, limit };

    // Cache for 60 seconds
    await this.redis.set(cacheKey, JSON.stringify(result), 'EX', 60);

    return result;
  }

  /**
   * 应用排序：sales_desc 用 OrderItem 子查询聚合；其余直接 orderBy。
   */
  private applySort(
    qb: import('typeorm').SelectQueryBuilder<ProductEntity>,
    sortBy: ProductSortBy,
  ) {
    switch (sortBy) {
      case 'sales_desc': {
        // 子查询：每个商品的销量合计
        const salesSub = this.orderItemRepo
          .createQueryBuilder('oi')
          .select('COALESCE(SUM(oi.quantity), 0)', 'sales')
          .where('oi.product_id = p.id');
        qb.addSelect(`(${salesSub.getQuery()})`, 'p_sales')
          .orderBy('p_sales', 'DESC')
          .addOrderBy('p.created_at', 'DESC');
        break;
      }
      case 'price_asc':
        qb.orderBy('p.price', 'ASC').addOrderBy('p.created_at', 'DESC');
        break;
      case 'price_desc':
        qb.orderBy('p.price', 'DESC').addOrderBy('p.created_at', 'DESC');
        break;
      case 'created_desc':
      default:
        qb.orderBy('p.created_at', 'DESC');
        break;
    }
  }

  async findBestsellers(limit = 10) {
    const take = Math.min(Math.max(limit, 1), 50);
    const cacheKey = 'products:bestsellers';
    const cached = await this.redis.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }

    const salesSub = this.orderItemRepo
      .createQueryBuilder('oi')
      .select('COALESCE(SUM(oi.quantity), 0)', 'sales')
      .where('oi.product_id = p.id');

    const list = await this.productRepo
      .createQueryBuilder('p')
      .where('p.status = :status', { status: ProductStatus.ON })
      .addSelect(`(${salesSub.getQuery()})`, 'p_sales')
      .orderBy('p_sales', 'DESC')
      .addOrderBy('p.created_at', 'DESC')
      .take(take)
      .getMany();

    const result = { list };
    await this.redis.set(cacheKey, JSON.stringify(result), 'EX', 300);
    return result;
  }

  async suggest(keyword: string, limit = 10) {
    const take = Math.min(Math.max(limit, 1), 20);
    const kw = keyword?.trim();
    const cacheKey = `products:suggest:${kw || 'all'}`;
    const cached = await this.redis.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }

    let names: string[] = [];
    if (kw) {
      const rows = await this.productRepo
        .createQueryBuilder('p')
        .select('p.name', 'name')
        .where('p.status = :status', { status: ProductStatus.ON })
        .andWhere('p.name LIKE :kw', { kw: `%${kw}%` })
        .orderBy('p.created_at', 'DESC')
        .take(take)
        .getRawMany<{ name: string }>();
      names = rows.map((r) => r.name);
    }

    const result = { list: names };
    await this.redis.set(cacheKey, JSON.stringify(result), 'EX', 60);
    return result;
  }

  async findOne(id: number) {
    const cacheKey = `product:${id}`;
    const cached = await this.redis.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }

    const product = await this.productRepo.findOne({ where: { id } });
    if (!product) {
      throw new NotFoundException(ErrorMessage[ErrorCode.PRODUCT_NOT_FOUND]);
    }

    await this.redis.set(cacheKey, JSON.stringify(product), 'EX', 60);
    return product;
  }

  async findRecommendations(opts: { limit?: number; excludeId?: number }) {
    const limit = Math.min(opts.limit ?? 10, 20);
    const excludeId = opts.excludeId ?? 0;
    const cacheKey = `products:recs:${limit}:${excludeId}`;

    const cached = await this.redis.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }

    const baseQb = this.productRepo
      .createQueryBuilder('p')
      .where('p.status = :status', { status: ProductStatus.ON })
      .andWhere('p.stock > 0');

    if (excludeId > 0) {
      baseQb.andWhere('p.id != :excludeId', { excludeId });
    }

    // 1. 先取推荐位商品（isRecommended=true）按 featuredSortOrder ASC + createdAt DESC
    const featured = await baseQb
      .clone()
      .andWhere('p.is_recommended = :isRec', { isRec: true })
      .orderBy('p.featured_sort_order', 'ASC')
      .addOrderBy('p.created_at', 'DESC')
      .take(limit)
      .getMany();

    let list = featured;

    // 2. 不足用非推荐商品按 createdAt DESC 补足
    if (list.length < limit) {
      const excludeIds = list.map((p) => p.id);
      const fillQb = baseQb.clone().andWhere('p.is_recommended = :isRec', { isRec: false });
      if (excludeIds.length > 0) {
        fillQb.andWhere('p.id NOT IN (:...excludeIds)', { excludeIds });
      }
      const fillers = await fillQb
        .orderBy('p.created_at', 'DESC')
        .take(limit - list.length)
        .getMany();
      list = [...list, ...fillers];
    }

    const result = { list };
    await this.redis.set(cacheKey, JSON.stringify(result), 'EX', 60);
    return result;
  }

  async create(dto: CreateProductDto) {
    const product = this.productRepo.create(dto);
    const saved = await this.productRepo.save(product);
    await this.clearProductCache();
    return saved;
  }

  async update(id: number, dto: UpdateProductDto) {
    const product = await this.productRepo.findOne({ where: { id } });
    if (!product) {
      throw new NotFoundException(ErrorMessage[ErrorCode.PRODUCT_NOT_FOUND]);
    }

    Object.assign(product, dto);
    const saved = await this.productRepo.save(product);
    await this.clearProductCache();
    await this.redis.del(`product:${id}`);
    return saved;
  }

  async remove(id: number) {
    const product = await this.productRepo.findOne({ where: { id } });
    if (!product) {
      throw new NotFoundException(ErrorMessage[ErrorCode.PRODUCT_NOT_FOUND]);
    }

    await this.productRepo.remove(product);
    await this.clearProductCache();
    await this.redis.del(`product:${id}`);
    return null;
  }

  async findAllCategories() {
    const cacheKey = 'categories:all';
    const cached = await this.redis.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }

    const categories = await this.categoryRepo.find({
      order: { sortOrder: 'ASC' },
    });

    await this.redis.set(cacheKey, JSON.stringify(categories), 'EX', 300);
    return categories;
  }

  async createCategory(dto: CreateCategoryDto) {
    const category = this.categoryRepo.create(dto);
    const saved = await this.categoryRepo.save(category);
    await this.clearCategoryCache();
    return saved;
  }

  async updateCategory(id: number, dto: UpdateCategoryDto) {
    const category = await this.categoryRepo.findOne({ where: { id } });
    if (!category) {
      throw new NotFoundException({
        code: ErrorCode.CATEGORY_NOT_FOUND,
        message: ErrorMessage[ErrorCode.CATEGORY_NOT_FOUND],
      });
    }
    Object.assign(category, dto);
    const saved = await this.categoryRepo.save(category);
    await this.clearCategoryCache();
    return saved;
  }

  async removeCategory(id: number) {
    const category = await this.categoryRepo.findOne({ where: { id } });
    if (!category) {
      throw new NotFoundException({
        code: ErrorCode.CATEGORY_NOT_FOUND,
        message: ErrorMessage[ErrorCode.CATEGORY_NOT_FOUND],
      });
    }
    const count = await this.productRepo.count({
      where: { categoryId: id, status: ProductStatus.ON },
    });
    if (count > 0) {
      throw new BadRequestException({
        code: ErrorCode.CATEGORY_HAS_PRODUCTS,
        message: ErrorMessage[ErrorCode.CATEGORY_HAS_PRODUCTS],
      });
    }
    await this.categoryRepo.remove(category);
    await this.clearCategoryCache();
    return null;
  }

  private async clearCategoryCache() {
    const keys = await this.redis.keys('categories:*');
    if (keys.length > 0) {
      await this.redis.del(...keys);
    }
  }

  private async clearProductCache() {
    const keys = await this.redis.keys('products:*');
    if (keys.length > 0) {
      await this.redis.del(...keys);
    }
  }
}
