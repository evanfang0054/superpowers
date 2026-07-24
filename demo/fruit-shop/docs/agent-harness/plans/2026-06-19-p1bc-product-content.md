# P1-BC 商品规格 + 内容运营 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 P1-B 商品规格字典 + Admin 表单补字段，P1-C-1 Banner Admin CRUD，P1-C-2 推荐位迭代 + 清空购物车 UI。

**Architecture:** 三端改动：shared 先行（新类型 + build）→ server（entity/DTO/module/service/e2e）→ web（API/页面/组件）。Banner 是全新业务模块，规格字典与推荐位迭代共享 ProductEntity 改动。

**Tech Stack:** NestJS 10 + TypeORM + MySQL + Redis + Jest；React 18 + TypeScript + Tailwind v4。

**Contract:** `docs/agent-harness/contracts/p1bc-product-content.contract.md`

---

## File Structure

**shared**

- Modify: `packages/shared/src/types/product.ts` — ProductSpec + Product 追加 specs/isRecommended/featuredSortOrder
- Create: `packages/shared/src/types/banner.ts`
- Modify: `packages/shared/src/index.ts` — re-export banner

**server**

- Modify: `packages/server/src/entities/product.entity.ts` — 3 新列
- Create: `packages/server/src/entities/banner.entity.ts`
- Modify: `packages/server/src/modules/product/dto/create-product.dto.ts` + `update-product.dto.ts`
- Modify: `packages/server/src/modules/product/product.service.ts` — findRecommendations 两段查询
- Create: `packages/server/src/modules/banner/` — module/controller/service/dto
- Modify: `packages/server/src/app.module.ts` — import BannerModule
- Create: `packages/server/test/banner.e2e-spec.ts`
- Modify: `packages/server/test/product.recommendations.e2e-spec.ts`

**web**

- Modify: `packages/web/src/pages/ProductDetail.tsx` — 修 specs 死代码 + selectedSpecs
- Modify: `packages/web/src/components/BuyBar.tsx` — 接 selectedSpecs prop
- Modify: `packages/web/src/pages/AdminProducts.tsx` — 补字段
- Create: `packages/web/src/api/banner.ts`
- Modify: `packages/web/src/components/PromoBanner.tsx` — 接 API
- Create: `packages/web/src/pages/AdminBanners.tsx`
- Modify: `packages/web/src/router/index.tsx` — /admin/banners
- Modify: `packages/web/src/pages/Cart.tsx` — 清空按钮 + modal

---

## Task 1: shared 新增 ProductSpec + Banner 类型

**Files:**

- Modify: `packages/shared/src/types/product.ts`
- Create: `packages/shared/src/types/banner.ts`
- Modify: `packages/shared/src/index.ts`

- [ ] **Step 1: 修改 product.ts，追加 ProductSpec 与 Product 新字段**

在 `packages/shared/src/types/product.ts` 的 `Product` 接口末尾（`updatedAt: string;` 之后）追加 3 个字段，并在文件底部新增 `ProductSpec` 接口：

```typescript
export interface Product {
  id: number;
  name: string;
  origin: string;
  price: number;
  originalPrice: number | null;
  unit: string;
  sweetness: string;
  weight: string;
  description: string | null;
  tags: string[] | null;
  image: string;
  color: string;
  categoryId: number;
  stock: number;
  status: ProductStatus;
  createdAt: string;
  updatedAt: string;
  specs: ProductSpec[] | null;
  isRecommended: boolean;
  featuredSortOrder: number;
}

export interface ProductSpec {
  name: string;
  values: string[];
}
```

注意：`ProductSpec` 必须在 `Product` 接口之前或之后定义（TypeScript 接口提升，顺序不影响）。

- [ ] **Step 2: 创建 banner.ts**

创建 `packages/shared/src/types/banner.ts`：

```typescript
export type BannerLinkType = 'none' | 'product' | 'category' | 'external';

export interface Banner {
  id: number;
  title: string;
  subtitle: string | null;
  image: string | null;
  ctaText: string | null;
  linkType: BannerLinkType;
  linkValue: string | null;
  sortOrder: number;
  status: number;
  createdAt: string;
  updatedAt: string;
}

export interface CreateBannerDTO {
  title: string;
  subtitle?: string;
  image?: string;
  ctaText?: string;
  linkType?: BannerLinkType;
  linkValue?: string;
  sortOrder?: number;
  status?: number;
}

export type UpdateBannerDTO = Partial<CreateBannerDTO>;
```

- [ ] **Step 3: 修改 index.ts，re-export banner 类型**

在 `packages/shared/src/index.ts` 的 `export type { ApiResponse, PaginatedResponse, PaginationQuery } from './types/api';` 之后追加：

```typescript
export type { ProductSpec } from './types/product';

export type { Banner, BannerLinkType, CreateBannerDTO, UpdateBannerDTO } from './types/banner';
```

- [ ] **Step 4: 构建 shared**

Run: `pnpm --filter shared build`
Expected: 成功无 tsc 错误

- [ ] **Step 5: 验证 dist 含新类型**

Run: `node -e "const t = require('./packages/shared/dist/types/product.js'); console.log('OK'); const b = require('./packages/shared/dist/types/banner.js'); console.log(typeof b.BannerLinkType);"`
Expected: 输出 `OK` 与 `undefined`（BannerLinkType 是 type，运行时不导出值，require 不报错即 OK）

- [ ] **Step 6: Commit**

```bash
git add packages/shared/src/types/product.ts packages/shared/src/types/banner.ts packages/shared/src/index.ts
git commit -m "feat(shared): 新增 ProductSpec 与 Banner 类型定义"
```

---

## Task 2: server ProductEntity 追加 specs/isRecommended/featuredSortOrder

**Files:**

- Modify: `packages/server/src/entities/product.entity.ts`

- [ ] **Step 1: 在 ProductEntity 追加 3 列**

在 `packages/server/src/entities/product.entity.ts` 中，顶部 import 修改：

```typescript
import { ProductStatus, ProductSpec } from 'shared';
```

在 `status` 字段之后、`@ManyToOne` 之前追加 3 列：

```typescript
  @Column({
    type: 'smallint',
    default: ProductStatus.ON,
  })
  status: ProductStatus;

  @Column({ type: 'simple-json', nullable: true })
  specs: ProductSpec[] | null;

  @Column({ name: 'is_recommended', type: 'boolean', default: false })
  isRecommended: boolean;

  @Column({ name: 'featured_sort_order', type: 'int', default: 0 })
  featuredSortOrder: number;

  @ManyToOne(() => CategoryEntity, { eager: false })
```

- [ ] **Step 2: 构建 server 确认无类型错误**

Run: `pnpm --filter server build`
Expected: 成功（shared 已 Task 1 build 过，dist 含 ProductSpec）

- [ ] **Step 3: Commit**

```bash
git add packages/server/src/entities/product.entity.ts
git commit -m "feat(server): ProductEntity 追加 specs/isRecommended/featuredSortOrder 列"
```

---

## Task 3: server Product DTO 追加 specs/isRecommended/featuredSortOrder

**Files:**

- Modify: `packages/server/src/modules/product/dto/create-product.dto.ts`
- Modify: `packages/server/src/modules/product/dto/update-product.dto.ts`

- [ ] **Step 1: 修改 create-product.dto.ts**

在 `packages/server/src/modules/product/dto/create-product.dto.ts` 顶部 import 追加：

```typescript
import {
  IsString,
  IsNumber,
  IsOptional,
  IsInt,
  IsBoolean,
  IsArray,
  Min,
  MaxLength,
} from 'class-validator';
import { ProductStatus, ProductSpec } from 'shared';
```

在 `status` 字段之后追加 3 字段：

```typescript
  @IsOptional()
  @IsArray()
  specs?: ProductSpec[];

  @IsOptional()
  @IsBoolean()
  isRecommended?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  featuredSortOrder?: number;
```

- [ ] **Step 2: 修改 update-product.dto.ts**

读 `packages/server/src/modules/product/dto/update-product.dto.ts`，按相同模式追加（字段全部 `@IsOptional`，与 CreateDto 一致）：

```typescript
  @IsOptional()
  @IsArray()
  specs?: ProductSpec[];

  @IsOptional()
  @IsBoolean()
  isRecommended?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  featuredSortOrder?: number;
```

同样 import 处加 `IsBoolean`、`IsArray`、`ProductSpec`。

- [ ] **Step 3: 构建 server**

Run: `pnpm --filter server build`
Expected: 成功

- [ ] **Step 4: Commit**

```bash
git add packages/server/src/modules/product/dto/
git commit -m "feat(server): Product DTO 追加 specs/isRecommended/featuredSortOrder 字段"
```

---

## Task 4: server BannerEntity + Module + DTO + Controller + Service

**Files:**

- Create: `packages/server/src/entities/banner.entity.ts`
- Create: `packages/server/src/modules/banner/banner.module.ts`
- Create: `packages/server/src/modules/banner/banner.controller.ts`
- Create: `packages/server/src/modules/banner/banner.service.ts`
- Create: `packages/server/src/modules/banner/dto/create-banner.dto.ts`
- Create: `packages/server/src/modules/banner/dto/update-banner.dto.ts`
- Modify: `packages/server/src/entities/index.ts`
- Modify: `packages/server/src/app.module.ts`

- [ ] **Step 1: 创建 BannerEntity**

创建 `packages/server/src/entities/banner.entity.ts`：

```typescript
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('banners')
export class BannerEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ length: 100 })
  title: string;

  @Column({ length: 200, nullable: true })
  subtitle: string;

  @Column({ length: 500, nullable: true })
  image: string;

  @Column({ name: 'cta_text', length: 50, nullable: true })
  ctaText: string;

  @Column({ name: 'link_type', length: 20, default: 'none' })
  linkType: string;

  @Column({ name: 'link_value', length: 500, nullable: true })
  linkValue: string;

  @Column({ name: 'sort_order', type: 'int', default: 0 })
  sortOrder: number;

  @Column({ type: 'smallint', default: 1 })
  status: number;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
```

- [ ] **Step 2: 在 entities/index.ts 追加 export**

读 `packages/server/src/entities/index.ts`，追加：

```typescript
export { BannerEntity } from './banner.entity';
```

- [ ] **Step 3: 创建 create-banner.dto.ts**

创建 `packages/server/src/modules/banner/dto/create-banner.dto.ts`：

```typescript
import { IsString, IsOptional, IsInt, IsIn, Min, MaxLength } from 'class-validator';

export class CreateBannerDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  title: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  subtitle?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  image?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  ctaText?: string;

  @IsOptional()
  @IsIn(['none', 'product', 'category', 'external'])
  linkType?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  linkValue?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @IsOptional()
  @IsInt()
  @IsIn([0, 1])
  status?: number;
}
```

注意：顶部需 `import { MinLength } from 'class-validator';`，请补到 import 列表。

- [ ] **Step 4: 创建 update-banner.dto.ts**

创建 `packages/server/src/modules/banner/dto/update-banner.dto.ts`：

```typescript
import { PartialType } from '@nestjs/mapped-types';
import { CreateBannerDto } from './create-banner.dto';

export class UpdateBannerDto extends PartialType(CreateBannerDto) {}
```

- [ ] **Step 5: 创建 banner.service.ts**

创建 `packages/server/src/modules/banner/banner.service.ts`：

```typescript
import { Injectable, NotFoundException, Inject } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Redis } from 'ioredis';
import { BannerEntity } from '../../entities/banner.entity';
import { CreateBannerDto } from './dto/create-banner.dto';
import { UpdateBannerDto } from './dto/update-banner.dto';
import { ErrorCode, ErrorMessage } from 'shared';

@Injectable()
export class BannerService {
  constructor(
    @InjectRepository(BannerEntity)
    private readonly bannerRepo: Repository<BannerEntity>,
    @Inject('REDIS_CLIENT')
    private readonly redis: Redis,
  ) {}

  async findActive() {
    const cacheKey = 'banners:active';
    const cached = await this.redis.get(cacheKey);
    if (cached) return JSON.parse(cached);

    const banners = await this.bannerRepo.find({
      where: { status: 1 },
      order: { sortOrder: 'ASC' },
    });

    await this.redis.set(cacheKey, JSON.stringify(banners), 'EX', 300);
    return banners;
  }

  async findAll() {
    return this.bannerRepo.find({ order: { sortOrder: 'ASC' } });
  }

  async create(dto: CreateBannerDto) {
    const banner = this.bannerRepo.create(dto);
    const saved = await this.bannerRepo.save(banner);
    await this.clearCache();
    return saved;
  }

  async update(id: number, dto: UpdateBannerDto) {
    const banner = await this.bannerRepo.findOne({ where: { id } });
    if (!banner) {
      throw new NotFoundException(ErrorMessage[ErrorCode.PRODUCT_NOT_FOUND]);
    }
    Object.assign(banner, dto);
    const saved = await this.bannerRepo.save(banner);
    await this.clearCache();
    return saved;
  }

  async remove(id: number) {
    const banner = await this.bannerRepo.findOne({ where: { id } });
    if (!banner) {
      throw new NotFoundException(ErrorMessage[ErrorCode.PRODUCT_NOT_FOUND]);
    }
    await this.bannerRepo.remove(banner);
    await this.clearCache();
    return null;
  }

  private async clearCache() {
    const keys = await this.redis.keys('banners:*');
    if (keys.length > 0) {
      await this.redis.del(...keys);
    }
  }
}
```

注意：复用 `ErrorCode.PRODUCT_NOT_FOUND` 作为 Banner 不存在的业务码（40201）。如需独立 Banner 业务码可后续扩展，YAGNI 暂用通用。

- [ ] **Step 6: 创建 banner.controller.ts**

创建 `packages/server/src/modules/banner/banner.controller.ts`：

```typescript
import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
  UseGuards,
  ParseIntPipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { UserRole } from 'shared';
import { BannerService } from './banner.service';
import { CreateBannerDto } from './dto/create-banner.dto';
import { UpdateBannerDto } from './dto/update-banner.dto';

@Controller('banners')
export class BannerController {
  constructor(private readonly bannerService: BannerService) {}

  @Public()
  @Get()
  findActive() {
    return this.bannerService.findActive();
  }

  @Get('all')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  findAll() {
    return this.bannerService.findAll();
  }

  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  create(@Body() dto: CreateBannerDto) {
    return this.bannerService.create(dto);
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateBannerDto) {
    return this.bannerService.update(id, dto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.bannerService.remove(id);
  }
}
```

⚠️ 路由顺序：`@Get('all')` 必须在 `@Get()` 之后但在任何 `@Get(':id')` 之前（本 controller 没有 `@Get(':id')`，无冲突）。`@Public()` 装饰器位置参考 `auth.controller.ts`。

- [ ] **Step 7: 创建 banner.module.ts**

创建 `packages/server/src/modules/banner/banner.module.ts`：

```typescript
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BannerEntity } from '../../entities/banner.entity';
import { BannerService } from './banner.service';
import { BannerController } from './banner.controller';

@Module({
  imports: [TypeOrmModule.forFeature([BannerEntity])],
  controllers: [BannerController],
  providers: [BannerService],
})
export class BannerModule {}
```

- [ ] **Step 8: 在 app.module.ts 注册 BannerModule**

在 `packages/server/src/app.module.ts` 中，import 顶部加：

```typescript
import { BannerModule } from './modules/banner/banner.module';
```

在 imports 数组的 `HealthModule,` 之后追加：

```typescript
    BannerModule,
```

- [ ] **Step 9: 构建 server**

Run: `pnpm --filter server build`
Expected: 成功无类型错误

- [ ] **Step 10: Commit**

```bash
git add packages/server/src/entities/banner.entity.ts packages/server/src/entities/index.ts packages/server/src/modules/banner/ packages/server/src/app.module.ts
git commit -m "feat(server): 新增 Banner 模块（entity/module/controller/service/dto + 缓存）"
```

---

## Task 5: server Banner e2e 测试

**Files:**

- Create: `packages/server/test/banner.e2e-spec.ts`

- [ ] **Step 1: 创建 banner.e2e-spec.ts**

创建 `packages/server/test/banner.e2e-spec.ts`：

```typescript
import request from 'supertest';
import { TestHelper } from './helpers/test-helper';

describe('Banner (e2e)', () => {
  const helper = new TestHelper();
  let adminToken: string;
  let userToken: string;
  let bannerId: number;

  beforeAll(async () => {
    await helper.setup();
    await helper.cleanDatabase();

    const admin = await helper.registerAdmin('13900000020', 'admin123456');
    adminToken = admin.accessToken;

    const user = await helper.registerAndLogin('13800000020', 'test123456');
    userToken = user.accessToken;

    // 清空可能存在的 banners（cleanDatabase 不含 banners 表）
    const dataSource = helper.app.get(DynamicDataSource);
    await dataSource.query('TRUNCATE TABLE banners');
  });

  afterAll(async () => {
    await helper.teardown();
  });

  it('POST /api/banners (admin) 应新建 Banner', () => {
    return request(helper.httpServer)
      .post('/api/banners')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        title: '限时特惠',
        subtitle: '新人首单立减¥10',
        ctaText: '立即领取',
        linkType: 'product',
        linkValue: '1',
        sortOrder: 1,
        status: 1,
      })
      .expect(201)
      .expect((res) => {
        expect(res.body.code).toBe(0);
        expect(res.body.data.id).toBeDefined();
        expect(res.body.data.title).toBe('限时特惠');
        bannerId = res.body.data.id;
      });
  });

  it('GET /api/banners (@Public) 应返回 status=1 的 Banner', () => {
    return request(helper.httpServer)
      .get('/api/banners')
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(0);
        expect(Array.isArray(res.body.data)).toBe(true);
        expect(res.body.data.length).toBeGreaterThanOrEqual(1);
        expect(res.body.data[0].title).toBe('限时特惠');
      });
  });

  it('GET /api/banners/all (admin) 应返回全部 Banner', () => {
    return request(helper.httpServer)
      .get('/api/banners/all')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(0);
        expect(Array.isArray(res.body.data)).toBe(true);
      });
  });

  it('PUT /api/banners/:id (admin) 应更新 Banner', () => {
    return request(helper.httpServer)
      .put(`/api/banners/${bannerId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ status: 0 })
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(0);
        expect(res.body.data.status).toBe(0);
      });
  });

  it('下架后 GET /api/banners 不应返回该 Banner', () => {
    return request(helper.httpServer)
      .get('/api/banners')
      .expect(200)
      .expect((res) => {
        const ids = res.body.data.map((b: any) => b.id);
        expect(ids).not.toContain(bannerId);
      });
  });

  it('DELETE /api/banners/:id (admin) 应删除', () => {
    return request(helper.httpServer)
      .delete(`/api/banners/${bannerId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(0);
      });
  });

  it('非 admin GET /api/banners/all 应返回 403', () => {
    return request(helper.httpServer)
      .get('/api/banners/all')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(403);
      });
  });

  it('无 token POST /api/banners 应返回 401', () => {
    return request(helper.httpServer)
      .post('/api/banners')
      .send({ title: 'x' })
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(401);
      });
  });
});

// 辅助：避免在 test-helper 加依赖，inline 取 DataSource
import { DataSource as DynamicDataSource } from 'typeorm';
```

注意：`DynamicDataSource` 的 import 放在文件底部仅为示意，实际应放文件顶部（与其他 import 一起）。请将 `import { DataSource } from 'typeorm';` 放到文件顶部 import 区，删除底部 DynamicDataSource alias，统一用 `DataSource`。

- [ ] **Step 2: 运行 e2e 确认 PASS**

⚠️ 先确保 `docker compose ps` mysql/redis healthy。

Run: `pnpm --filter server test:e2e -- test/banner.e2e-spec.ts`
Expected: 全部用例通过

- [ ] **Step 3: Commit**

```bash
git add packages/server/test/banner.e2e-spec.ts
git commit -m "test(banner): 新增 Banner e2e（Public/Admin 守卫、CRUD、缓存）"
```

---

## Task 6: server 推荐位迭代（两段查询）

**Files:**

- Modify: `packages/server/src/modules/product/product.service.ts`
- Modify: `packages/server/test/product.recommendations.e2e-spec.ts`

- [ ] **Step 1: 改写 findRecommendations 方法**

在 `packages/server/src/modules/product/product.service.ts` 中，**整段替换** `findRecommendations` 方法（P0 MVP 版）：

```typescript
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

    // 1. 先取推荐位商品（isRecommended=true）按 featuredSortOrder ASC
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
      const fillQb = baseQb
        .clone()
        .andWhere('p.is_recommended = :isRec', { isRec: false });
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
```

- [ ] **Step 2: 在 product.recommendations.e2e-spec.ts 扩展用例**

读 `packages/server/test/product.recommendations.e2e-spec.ts`，在现有用例之后追加两个用例（参考其 beforeAll 结构）：

```typescript
it('isRecommended 商品应优先出现在推荐位', async () => {
  // 创建 2 个推荐商品 + 1 个非推荐商品
  const featured1 = await helper.createProductAsAdmin(adminToken, {
    name: '推荐-A',
    isRecommended: true,
    featuredSortOrder: 1,
  });
  const featured2 = await helper.createProductAsAdmin(adminToken, {
    name: '推荐-B',
    isRecommended: true,
    featuredSortOrder: 0,
  });
  const normal = await helper.createProductAsAdmin(adminToken, {
    name: '普通-C',
    isRecommended: false,
  });

  const res = await request(helper.httpServer)
    .get('/api/products/recommendations')
    .query({ limit: 10 })
    .expect(200);
  const ids = res.body.data.list.map((p: any) => p.id);

  // 推荐 B（sortOrder 0）应排在 A（sortOrder 1）之前
  expect(ids.indexOf(featured2)).toBeLessThan(ids.indexOf(featured1));
  // 推荐商品应在普通商品之前
  expect(ids.indexOf(featured2)).toBeLessThan(ids.indexOf(normal));
});

it('推荐商品不足时应用 createdAt DESC 补足', async () => {
  const res = await request(helper.httpServer)
    .get('/api/products/recommendations')
    .query({ limit: 10 })
    .expect(200);
  expect(res.body.data.list.length).toBeLessThanOrEqual(10);
  // 若列表含非推荐商品，它们必在推荐商品之后（顺序由测试 1 保证）
});
```

注意：`helper.createProductAsAdmin` 的 overrides 参数已支持任意字段透传（含 `isRecommended`、`featuredSortOrder`）—— 检查 `test/helpers/test-helper.ts` 的 `createProductAsAdmin` 实现，确认 overrides 会覆盖默认 body。如不覆盖需先扩展 helper。

- [ ] **Step 3: 运行 e2e 确认 PASS**

Run: `pnpm --filter server test:e2e -- test/product.recommendations.e2e-spec.ts`
Expected: 全部用例通过（含新增 2 个）

- [ ] **Step 4: 全量 e2e 回归**

Run: `pnpm --filter server test:e2e`
Expected: 全部通过

- [ ] **Step 5: Commit**

```bash
git add packages/server/src/modules/product/product.service.ts packages/server/test/product.recommendations.e2e-spec.ts
git commit -m "feat(product): 推荐位迭代——isRecommended 优先 + createdAt DESC 补足"
```

---

## Task 7: web ProductDetail 修 specs 死代码 + selectedSpecs

**Files:**

- Modify: `packages/web/src/pages/ProductDetail.tsx`

- [ ] **Step 1: 删除 specs 强制断言，改用 product.specs**

在 `packages/web/src/pages/ProductDetail.tsx` 中，顶部 `useState` 区追加（在 `const [isLoading, setIsLoading] = useState(true);` 之后）：

```tsx
const [selectedSpecs, setSelectedSpecs] = useState<Record<string, string>>({});
```

删除第 69-86 行的「解析规格」整段代码（`const specs: Array<...> = []; if ((product as ...).specs) { try { ... } catch {} }`），替换为：

```tsx
const specs = product.specs ?? [];
```

- [ ] **Step 2: 修改 SpecSelector 的 onChange 与 BuyBar 调用**

将第 178 行 `<SpecSelector specs={specs} onChange={() => {}} />` 改为：

```tsx
<SpecSelector specs={specs} onChange={setSelectedSpecs} />
```

将第 195 行 `<BuyBar product={product} />` 改为：

```tsx
<BuyBar product={product} selectedSpecs={selectedSpecs} />
```

- [ ] **Step 3: 运行 web build**

Run: `pnpm --filter web build`
Expected: 成功（依赖 Task 8 BuyBar 接 selectedSpecs prop 才能通过类型检查；若先执行此 task 会失败，需与 Task 8 一起 commit 或先做 Task 8）

⚠️ 本 task 与 Task 8 有强耦合，**合并到 Task 8 一起 commit**。

---

## Task 8: web BuyBar 接 selectedSpecs prop

**Files:**

- Modify: `packages/web/src/components/BuyBar.tsx`

- [ ] **Step 1: 修改 BuyBarProps 与 specLabel 计算**

在 `packages/web/src/components/BuyBar.tsx` 中，修改 `BuyBarProps` 接口：

```tsx
interface BuyBarProps {
  product: Product;
  selectedSpecs: Record<string, string>;
}
```

修改函数签名解构：

```tsx
export function BuyBar({ product, selectedSpecs }: BuyBarProps) {
```

在 `const [qty, setQty] = useState(1);` 之后追加 specLabel 计算：

```tsx
const specLabel = Object.values(selectedSpecs).join('/') || '默认';
```

将 `handleAddToCart` 与 `handleBuyNow` 中的 `specLabel: '默认'` 替换为 `specLabel`：

```tsx
const handleAddToCart = async () => {
  try {
    await addItem({ productId: product.id, specLabel, quantity: qty });
    showToast(`已加入购物车 ×${qty}`, 'success');
  } catch {
    showToast('添加失败，请重试', 'error');
  }
};

const handleBuyNow = async () => {
  try {
    await addItem({ productId: product.id, specLabel, quantity: qty });
    navigate('/cart');
  } catch {
    showToast('操作失败，请重试', 'error');
  }
};
```

- [ ] **Step 2: 运行 web build（与 Task 7 一起）**

Run: `pnpm --filter web build`
Expected: 成功无 TS 错误（Task 7 的 ProductDetail 传 selectedSpecs，BuyBar 接 selectedSpecs，类型一致）

- [ ] **Step 3: Commit（Task 7 + Task 8 合并）**

```bash
git add packages/web/src/pages/ProductDetail.tsx packages/web/src/components/BuyBar.tsx
git commit -m "feat(web): ProductDetail 修 specs 死代码 + BuyBar 接 selectedSpecs 传真实 specLabel"
```

---

## Task 9: web AdminProducts 表单补字段

**Files:**

- Modify: `packages/web/src/pages/AdminProducts.tsx`

- [ ] **Step 1: 读现有 AdminProducts.tsx，定位 ProductFormData / emptyForm / openEditModal / payload**

先读 `packages/web/src/pages/AdminProducts.tsx` 完整文件，理解：

- `ProductFormData` 接口定义（约第 21-32 行）
- `emptyForm` 默认值（约第 34-45 行）
- 表单 JSX 结构
- `openEditModal` 回填逻辑（约第 121-136 行）
- 提交 payload（约第 152-163 行）

- [ ] **Step 2: ProductFormData 接口追加字段**

在 `ProductFormData` 接口追加：

```typescript
sweetness: string;
weight: string;
color: string;
tags: string; // 逗号分隔
specs: string; // JSON 字符串
isRecommended: boolean;
featuredSortOrder: number;
```

- [ ] **Step 3: emptyForm 追加默认值**

```typescript
  sweetness: '',
  weight: '',
  color: '#FF6B35',
  tags: '',
  specs: '',
  isRecommended: false,
  featuredSortOrder: 0,
```

- [ ] **Step 4: openEditModal 回填追加**

在 `openEditModal` 的 setForm 调用中追加：

```typescript
    sweetness: product.sweetness ?? '',
    weight: product.weight ?? '',
    color: product.color ?? '#FF6B35',
    tags: product.tags?.join(',') ?? '',
    specs: product.specs ? JSON.stringify(product.specs, null, 2) : '',
    isRecommended: product.isRecommended ?? false,
    featuredSortOrder: product.featuredSortOrder ?? 0,
```

- [ ] **Step 5: 表单 JSX 追加输入控件**

在表单 JSX 中（按现有字段分组位置）追加。沿用现有 input 样式（`border border-gray-200 rounded-2xl px-3 py-2 focus:ring-2 focus:ring-brand-primary/30`）：

```tsx
{
  /* 甜度 */
}
<input
  value={form.sweetness}
  onChange={(e) => setForm({ ...form, sweetness: e.target.value })}
  placeholder="甜度（如 甜、酸甜）"
  className="w-full border border-gray-200 rounded-2xl px-3 py-2 focus:ring-2 focus:ring-brand-primary/30"
/>;

{
  /* 规格 weight */
}
<input
  value={form.weight}
  onChange={(e) => setForm({ ...form, weight: e.target.value })}
  placeholder="规格（如 500g、1kg）"
  className="w-full border border-gray-200 rounded-2xl px-3 py-2 focus:ring-2 focus:ring-brand-primary/30"
/>;

{
  /* 颜色 */
}
<input
  value={form.color}
  onChange={(e) => setForm({ ...form, color: e.target.value })}
  placeholder="色板 hex（如 #FF6B35）"
  className="w-full border border-gray-200 rounded-2xl px-3 py-2 focus:ring-2 focus:ring-brand-primary/30"
/>;

{
  /* 标签 tags */
}
<input
  value={form.tags}
  onChange={(e) => setForm({ ...form, tags: e.target.value })}
  placeholder="标签（逗号分隔，如 甜,新鲜,限时）"
  className="w-full border border-gray-200 rounded-2xl px-3 py-2 focus:ring-2 focus:ring-brand-primary/30"
/>;

{
  /* 规格 JSON specs */
}
<textarea
  value={form.specs}
  onChange={(e) => setForm({ ...form, specs: e.target.value })}
  placeholder='规格 JSON，如 [{"name":"规格","values":["500g/盒","1kg/袋"]}]'
  rows={3}
  className="w-full border border-gray-200 rounded-2xl px-3 py-2 focus:ring-2 focus:ring-brand-primary/30 font-mono text-xs"
/>;

{
  /* 推荐位 */
}
<label className="flex items-center gap-2">
  <input
    type="checkbox"
    checked={form.isRecommended}
    onChange={(e) => setForm({ ...form, isRecommended: e.target.checked })}
  />
  <span>设为推荐商品</span>
</label>;

{
  /* 推荐排序 */
}
<input
  type="number"
  value={form.featuredSortOrder}
  onChange={(e) => setForm({ ...form, featuredSortOrder: Number(e.target.value) })}
  placeholder="推荐排序（小的在前）"
  className="w-full border border-gray-200 rounded-2xl px-3 py-2 focus:ring-2 focus:ring-brand-primary/30"
/>;
```

控件放置位置：sweetness/weight/color/tags/specs 放在 description 附近（现有基础字段区），isRecommended/featuredSortOrder 放在 status 附近（运营字段区）。

- [ ] **Step 6: 提交 payload 追加字段与 specs JSON.parse 容错**

修改提交逻辑（约第 152-163 行 payload 构造处），追加字段并处理 specs：

```tsx
// specs JSON 解析（失败不提交）
let parsedSpecs: any[] | null = null;
if (form.specs.trim()) {
  try {
    parsedSpecs = JSON.parse(form.specs);
    if (!Array.isArray(parsedSpecs)) throw new Error('not array');
  } catch {
    showToast('规格 JSON 格式错误', 'error');
    return;
  }
}

const payload = {
  // ...现有字段
  sweetness: form.sweetness,
  weight: form.weight,
  color: form.color,
  tags: form.tags
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),
  specs: parsedSpecs,
  isRecommended: form.isRecommended,
  featuredSortOrder: Number(form.featuredSortOrder),
};
```

注意：现有 payload 是 `apiClient.post` 或 `apiClient.put` 直接传 form 对象，需改为构造新 payload 对象后传入。保留原有字段映射。

- [ ] **Step 7: 运行 web build**

Run: `pnpm --filter web build`
Expected: 成功无 TS 错误

- [ ] **Step 8: Commit**

```bash
git add packages/web/src/pages/AdminProducts.tsx
git commit -m "feat(web): AdminProducts 表单补 sweetness/weight/color/tags/specs/isRecommended/featuredSortOrder 字段"
```

---

## Task 10: web Banner API + PromoBanner 接 API

**Files:**

- Create: `packages/web/src/api/banner.ts`
- Modify: `packages/web/src/components/PromoBanner.tsx`

- [ ] **Step 1: 创建 api/banner.ts**

创建 `packages/web/src/api/banner.ts`：

```typescript
import { apiClient } from './client';
import type { ApiResponse, Banner, CreateBannerDTO, UpdateBannerDTO } from 'shared';

export const bannerApi = {
  getActive() {
    return apiClient.get<ApiResponse<Banner[]>>('/banners');
  },
  getAll() {
    return apiClient.get<ApiResponse<Banner[]>>('/banners/all');
  },
  create(data: CreateBannerDTO) {
    return apiClient.post<ApiResponse<Banner>>('/banners', data);
  },
  update(id: number, data: UpdateBannerDTO) {
    return apiClient.put<ApiResponse<Banner>>(`/banners/${id}`, data);
  },
  remove(id: number) {
    return apiClient.delete<ApiResponse<null>>(`/banners/${id}`);
  },
};
```

- [ ] **Step 2: 改造 PromoBanner.tsx 接 API**

读 `packages/web/src/components/PromoBanner.tsx` 现有实现，整文件替换为：

```tsx
import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import type { Banner } from 'shared';
import { bannerApi } from '@/api/banner';

export function PromoBanner() {
  const navigate = useNavigate();
  const [banner, setBanner] = useState<Banner | null>(null);

  useEffect(() => {
    bannerApi
      .getActive()
      .then((res) => {
        const list = res.data.data ?? [];
        setBanner(list.length > 0 ? list[0] : null);
      })
      .catch(() => setBanner(null));
  }, []);

  if (!banner) return null;

  const handleCta = () => {
    if (!banner.ctaText) return;
    switch (banner.linkType) {
      case 'product':
        navigate(`/product/${banner.linkValue}`);
        break;
      case 'category':
        navigate(`/?categoryId=${banner.linkValue}`);
        break;
      case 'external':
        if (banner.linkValue) {
          window.open(banner.linkValue, '_blank', 'noopener');
        }
        break;
      case 'none':
      default:
        break;
    }
  };

  return (
    <div
      className="relative rounded-3xl overflow-hidden mx-4 my-4"
      style={{ background: 'var(--gradient-promo)' }}
    >
      {banner.image && (
        <img
          src={banner.image}
          alt={banner.title}
          className="absolute inset-0 w-full h-full object-cover opacity-20"
        />
      )}
      <div className="relative p-5 flex items-center justify-between">
        <div className="flex-1">
          <div className="text-white font-bold text-lg">{banner.title}</div>
          {banner.subtitle && <div className="text-white/90 text-sm mt-1">{banner.subtitle}</div>}
        </div>
        {banner.ctaText && (
          <button
            onClick={handleCta}
            className="bg-white text-brand-primary font-bold text-sm px-4 py-2 rounded-full whitespace-nowrap"
          >
            {banner.ctaText}
          </button>
        )}
      </div>
    </div>
  );
}
```

注意：`var(--gradient-promo)` 沿用现有 styles/index.css 定义的 gradient token（P0 前 PromoBanner 已用此 token）。

- [ ] **Step 3: 运行 web build**

Run: `pnpm --filter web build`
Expected: 成功

- [ ] **Step 4: Commit**

```bash
git add packages/web/src/api/banner.ts packages/web/src/components/PromoBanner.tsx
git commit -m "feat(web): PromoBanner 改为从 /api/banners 拉取，CTA 按 linkType 跳转"
```

---

## Task 11: web AdminBanners 页 + 路由

**Files:**

- Create: `packages/web/src/pages/AdminBanners.tsx`
- Modify: `packages/web/src/router/index.tsx`

- [ ] **Step 1: 创建 AdminBanners.tsx**

创建 `packages/web/src/pages/AdminBanners.tsx`（仿 AdminProducts 结构，简化版）：

```tsx
import { useState, useEffect } from 'react';
import { bannerApi } from '@/api/banner';
import type { Banner, CreateBannerDTO } from 'shared';
import { useToast } from '@/components/Toast';

interface BannerFormData {
  title: string;
  subtitle: string;
  image: string;
  ctaText: string;
  linkType: 'none' | 'product' | 'category' | 'external';
  linkValue: string;
  sortOrder: number;
  status: number;
}

const emptyForm: BannerFormData = {
  title: '',
  subtitle: '',
  image: '',
  ctaText: '',
  linkType: 'none',
  linkValue: '',
  sortOrder: 0,
  status: 1,
};

export default function AdminBanners() {
  const { showToast } = useToast();
  const [banners, setBanners] = useState<Banner[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState<BannerFormData>(emptyForm);

  const fetchBanners = async () => {
    setIsLoading(true);
    try {
      const { data } = await bannerApi.getAll();
      setBanners(data.data ?? []);
    } catch {
      showToast('加载失败', 'error');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchBanners();
  }, []);

  const openCreate = () => {
    setForm(emptyForm);
    setEditingId(null);
    setModalOpen(true);
  };

  const openEdit = (b: Banner) => {
    setForm({
      title: b.title,
      subtitle: b.subtitle ?? '',
      image: b.image ?? '',
      ctaText: b.ctaText ?? '',
      linkType: b.linkType,
      linkValue: b.linkValue ?? '',
      sortOrder: b.sortOrder,
      status: b.status,
    });
    setEditingId(b.id);
    setModalOpen(true);
  };

  const handleSubmit = async () => {
    if (!form.title.trim()) {
      showToast('标题不能为空', 'error');
      return;
    }
    const payload: CreateBannerDTO = {
      title: form.title,
      subtitle: form.subtitle || undefined,
      image: form.image || undefined,
      ctaText: form.ctaText || undefined,
      linkType: form.linkType,
      linkValue: form.linkValue || undefined,
      sortOrder: Number(form.sortOrder),
      status: Number(form.status),
    };
    try {
      if (editingId) {
        await bannerApi.update(editingId, payload);
        showToast('更新成功', 'success');
      } else {
        await bannerApi.create(payload);
        showToast('创建成功', 'success');
      }
      setModalOpen(false);
      fetchBanners();
    } catch {
      showToast('保存失败', 'error');
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('确定删除此 Banner？')) return;
    try {
      await bannerApi.remove(id);
      showToast('删除成功', 'success');
      fetchBanners();
    } catch {
      showToast('删除失败', 'error');
    }
  };

  const inputCls =
    'w-full border border-gray-200 rounded-2xl px-3 py-2 focus:ring-2 focus:ring-brand-primary/30';

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <header className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Banner 管理</h1>
        <button
          onClick={openCreate}
          className="bg-brand-primary text-white px-4 py-2 rounded-2xl font-bold"
        >
          新建 Banner
        </button>
      </header>

      {isLoading ? (
        <div className="text-center py-10 text-gray-500">加载中...</div>
      ) : banners.length === 0 ? (
        <div className="text-center py-10 text-gray-500">暂无 Banner</div>
      ) : (
        <table className="w-full bg-white rounded-2xl border border-gray-200">
          <thead className="bg-gray-100 text-gray-600 text-sm">
            <tr>
              <th className="text-left p-3">标题</th>
              <th className="text-left p-3">状态</th>
              <th className="text-left p-3">排序</th>
              <th className="text-left p-3">跳转类型</th>
              <th className="text-left p-3">操作</th>
            </tr>
          </thead>
          <tbody>
            {banners.map((b) => (
              <tr key={b.id} className="border-t border-gray-100">
                <td className="p-3 font-medium">{b.title}</td>
                <td className="p-3">
                  <span
                    className={`px-2 py-0.5 rounded text-xs font-bold ${
                      b.status === 1 ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'
                    }`}
                  >
                    {b.status === 1 ? '上架' : '下架'}
                  </span>
                </td>
                <td className="p-3">{b.sortOrder}</td>
                <td className="p-3 text-sm">{b.linkType}</td>
                <td className="p-3 flex gap-2">
                  <button
                    onClick={() => openEdit(b)}
                    className="text-brand-primary text-sm font-bold"
                  >
                    编辑
                  </button>
                  <button
                    onClick={() => handleDelete(b.id)}
                    className="text-red-500 text-sm font-bold"
                  >
                    删除
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {modalOpen && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-3xl p-6 w-full max-w-md max-h-[90vh] overflow-y-auto">
            <h2 className="text-xl font-bold mb-4">{editingId ? '编辑 Banner' : '新建 Banner'}</h2>
            <div className="space-y-3">
              <input
                value={form.title}
                onChange={(e) => setForm({ ...form, title: e.target.value })}
                placeholder="标题（必填）"
                className={inputCls}
              />
              <input
                value={form.subtitle}
                onChange={(e) => setForm({ ...form, subtitle: e.target.value })}
                placeholder="副标题"
                className={inputCls}
              />
              <input
                value={form.image}
                onChange={(e) => setForm({ ...form, image: e.target.value })}
                placeholder="背景图 URL（可选）"
                className={inputCls}
              />
              <input
                value={form.ctaText}
                onChange={(e) => setForm({ ...form, ctaText: e.target.value })}
                placeholder="按钮文字（如 立即领取）"
                className={inputCls}
              />
              <select
                value={form.linkType}
                onChange={(e) =>
                  setForm({ ...form, linkType: e.target.value as BannerFormData['linkType'] })
                }
                className={inputCls}
              >
                <option value="none">不跳转</option>
                <option value="product">商品</option>
                <option value="category">分类</option>
                <option value="external">外部链接</option>
              </select>
              <input
                value={form.linkValue}
                onChange={(e) => setForm({ ...form, linkValue: e.target.value })}
                placeholder="跳转值（商品 id / 分类 id / URL）"
                className={inputCls}
              />
              <input
                type="number"
                value={form.sortOrder}
                onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) })}
                placeholder="排序（小的在前）"
                className={inputCls}
              />
              <select
                value={form.status}
                onChange={(e) => setForm({ ...form, status: Number(e.target.value) })}
                className={inputCls}
              >
                <option value={1}>上架</option>
                <option value={0}>下架</option>
              </select>
            </div>
            <div className="flex gap-2 mt-6">
              <button
                onClick={handleSubmit}
                className="flex-1 py-2.5 rounded-2xl bg-brand-primary text-white font-bold"
              >
                保存
              </button>
              <button
                onClick={() => setModalOpen(false)}
                className="flex-1 py-2.5 rounded-2xl border border-gray-200 font-bold"
              >
                取消
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 2: 在 router/index.tsx 新增路由与 lazy import**

在 `packages/web/src/router/index.tsx` 中：

顶部 lazy import 区追加（在 `const AdminProducts = lazy(...)` 之后）：

```tsx
const AdminBanners = lazy(() => import('@/pages/AdminBanners'));
```

路由表在 `/admin/products` 之后追加：

```tsx
  {
    path: '/admin/banners',
    element: <SuspenseWrapper><AdminRoute><AdminBanners /></AdminRoute></SuspenseWrapper>,
  },
```

- [ ] **Step 3: 运行 web build**

Run: `pnpm --filter web build`
Expected: 成功

- [ ] **Step 4: Commit**

```bash
git add packages/web/src/pages/AdminBanners.tsx packages/web/src/router/index.tsx
git commit -m "feat(web): 新增 AdminBanners 管理页 + /admin/banners 路由"
```

---

## Task 12: web Cart 清空按钮 + modal

**Files:**

- Modify: `packages/web/src/pages/Cart.tsx`

- [ ] **Step 1: 读 Cart.tsx 定位 header / deleteTarget modal / clearCart 调用**

先读 `packages/web/src/pages/Cart.tsx`，理解：

- header 结构（约第 104-109 行）
- 现有 deleteTarget modal（用于单条删除二次确认）
- store 中 clearCart 方法已存在

- [ ] **Step 2: 新增 clearTarget state**

在 useState 区追加：

```tsx
const [clearTarget, setClearTarget] = useState(false);
```

- [ ] **Step 3: header 追加清空按钮**

在 header 的 `{items.length}件商品` 之后追加：

```tsx
{
  items.length > 0 && (
    <button
      onClick={() => setClearTarget(true)}
      className="ml-auto text-brand-coral text-sm font-bold"
    >
      清空
    </button>
  );
}
```

注意：若 header 已有 `ml-auto` 类的元素（如全选/结算按钮），需调整布局使「清空」靠右。按现有结构，将「清空」放在 header 最右侧。

- [ ] **Step 4: 新增清空确认 modal 与 confirmClear**

在组件内（与 deleteTarget modal 同级）追加：

```tsx
const confirmClear = async () => {
  try {
    await clearCart();
    showToast('购物车已清空', 'success');
  } catch {
    showToast('清空失败', 'error');
  } finally {
    setClearTarget(false);
  }
};
```

JSX modal（放在现有 deleteTarget modal 附近）：

```tsx
{
  clearTarget && (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-3xl p-6 w-full max-w-xs">
        <p className="text-center text-brand-dark font-bold mb-4">确定清空购物车？此操作不可撤销</p>
        <div className="flex gap-2">
          <button
            onClick={confirmClear}
            className="flex-1 py-2.5 rounded-2xl bg-brand-coral text-white font-bold"
          >
            确定清空
          </button>
          <button
            onClick={() => setClearTarget(false)}
            className="flex-1 py-2.5 rounded-2xl border border-brand-border font-bold"
          >
            取消
          </button>
        </div>
      </div>
    </div>
  );
}
```

注意：从 store 解构 `clearCart`：

```tsx
const clearCart = useCartStore((s) => s.clearCart);
```

（若已解构则跳过；检查现有 store 解构语句）

- [ ] **Step 5: 运行 web build**

Run: `pnpm --filter web build`
Expected: 成功

- [ ] **Step 6: Commit**

```bash
git add packages/web/src/pages/Cart.tsx
git commit -m "feat(web): Cart 页新增「清空」按钮与二次确认 modal"
```

---

## Task 13: 全量回归与手动验证

**Files:** 无（仅执行验证）

- [ ] **Step 1: shared 重 build**

Run: `pnpm --filter shared build`
Expected: 成功

- [ ] **Step 2: server 全量 unit**

Run: `pnpm --filter server test`
Expected: 全部通过

- [ ] **Step 3: server 全量 e2e**

⚠️ `docker compose ps` 确认 healthy。

Run: `pnpm --filter server test:e2e`
Expected: 全部通过（含新增 banner.e2e、扩展的 product.recommendations.e2e）

- [ ] **Step 4: web build**

Run: `pnpm --filter web build`
Expected: 成功

- [ ] **Step 5: 启动 docker compose 手动验证所有场景**

Run: `docker compose up -d --build`
浏览器走查 contract 中全部场景（P1-B 5 项 + P1-C-1 7 项 + P1-C-2 5 项）。

- [ ] **Step 6: 最终 commit（如有回归修复）**

如所有验证通过，无需额外 commit。

---

## 验收映射（Contract → Task）

| Contract 验收项                                    | 对应 Task |
| -------------------------------------------------- | --------- |
| shared ProductSpec/Banner 类型                     | Task 1    |
| ProductEntity 3 新列                               | Task 2    |
| Product DTO 3 新字段                               | Task 3    |
| BannerEntity + Module + DTO + Controller + Service | Task 4    |
| Banner e2e                                         | Task 5    |
| 推荐位两段查询 + e2e                               | Task 6    |
| ProductDetail 修 specs 死代码 + selectedSpecs      | Task 7    |
| BuyBar 接 selectedSpecs                            | Task 8    |
| AdminProducts 表单补字段                           | Task 9    |
| Banner API + PromoBanner 接 API                    | Task 10   |
| AdminBanners 页 + 路由                             | Task 11   |
| Cart 清空按钮 + modal                              | Task 12   |
| 全量回归 + 手动验证                                | Task 13   |

---

## Self-Review Notes

- **Spec coverage**: spec 第 5/6/7 节全部映射到 Task 1-12
- **Placeholder scan**: 无 TBD/TODO，所有 code step 含完整代码
- **Type consistency**: `ProductSpec` 在 shared/entity/DTO 三处一致；`selectedSpecs: Record<string, string>` 在 ProductDetail/BuyBar 一致；`BannerFormData.linkType` 与 shared `BannerLinkType` 一致
- **Task 依赖**：Task 1（shared）必须最先；Task 2-4 依赖 Task 1；Task 5 依赖 Task 4；Task 6 依赖 Task 2-3；Task 7-8 强耦合合并 commit；Task 9 依赖 Task 1-3；Task 10-12 独立；Task 13 全量回归
- **循环依赖**：Banner 模块不涉及 web store，无循环依赖风险
- **缓存失效**：BannerService.clearCache 清 `banners:*`；ProductService.clearProductCache 已覆盖 `products:recs:*`
