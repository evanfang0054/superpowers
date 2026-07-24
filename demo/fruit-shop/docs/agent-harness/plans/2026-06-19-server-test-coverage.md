# 后端测试全量补齐 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `packages/server` 补齐 service 层 + common 层单测、扩写 5 个 e2e 文件的异常/权限/校验路径，使 `pnpm --filter server test:unit` 与 `pnpm --filter server test:e2e` 全绿。

**Architecture:** 纯 mock 单测（不依赖真实 DB/Redis，可并行）+ 真实链路 e2e（依赖 docker compose 起的 MySQL + Redis）。每个 spec 文件对应一个 source 文件，e2e 在原有文件上追加 describe block。

**Tech Stack:** Jest 30 + ts-jest + supertest + NestJS Testing Module

**关联文档：**

- Spec: `docs/agent-harness/specs/2026-06-19-server-test-coverage-design.md`
- Contract: `docs/agent-harness/contracts/server-test-coverage.contract.md`

**通用约定（所有 service spec）：**

- `mockRepository = { findOne: jest.fn(), find: jest.fn(), count: jest.fn(), create: jest.fn(), save: jest.fn(), remove: jest.fn(), createQueryBuilder: jest.fn() }`
- `mockLogger = { setContext: jest.fn(), info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() }`
- `mockRedis = { get: jest.fn(), set: jest.fn(), keys: jest.fn(), del: jest.fn() }`
- 测试目标用 `new XxxService(...mocks)` 直接实例化，跳过 Nest DI（避免 module 编译慢）
- 异常断言用 `await expect(fn()).rejects.toThrow(ConflictException)` 或 `.rejects.toMatchObject({ message })`

**前置条件（一次性，Task 0 完成后所有 task 复用）：**

- `pnpm --filter shared build` 已执行（保证 shared dist 最新，否则 jest moduleNameMapper 拉到旧 dist）

---

## Task 0: 前置准备

**Files:**

- 验证：`packages/shared/dist/`、`packages/server/.env.test`

- [ ] **Step 1: 构建 shared**

```bash
pnpm --filter shared build
```

Expected: `dist/` 下生成 `constants.js`、`types/*.js`

- [ ] **Step 2: 确认 .env.test 存在且指向 test 库**

Run: `cat packages/server/.env.test`
Expected: `DB_DATABASE=fruit_shop_test`、`REDIS_DB=1`。若不存在，复制 `.env.example` 后修改这两个值。

- [ ] **Step 3: 确认现有测试基线全绿**

```bash
pnpm --filter server test:unit
```

Expected: 6 个 controller spec 全部 PASS

---

## Task 1: user.service.spec.ts（最简单的 service，作为模板）

**Files:**

- Create: `packages/server/src/modules/user/user.service.spec.ts`
- Source: `packages/server/src/modules/user/user.service.ts`

- [ ] **Step 1: 写 spec 文件**

```typescript
import { NotFoundException } from '@nestjs/common';
import { UserService } from './user.service';

describe('UserService', () => {
  let service: UserService;
  let userRepo: any;

  beforeEach(() => {
    userRepo = {
      findOne: jest.fn(),
      save: jest.fn(),
    };
    service = new UserService(userRepo);
  });

  describe('getProfile', () => {
    it('should return user when found', async () => {
      const user = { id: 1, phone: '13800000001', role: 'user' };
      userRepo.findOne.mockResolvedValue(user);

      const result = await service.getProfile(1);

      expect(result).toEqual(user);
      expect(userRepo.findOne).toHaveBeenCalledWith({ where: { id: 1 } });
    });

    it('should throw NotFoundException when user not found', async () => {
      userRepo.findOne.mockResolvedValue(null);

      await expect(service.getProfile(999)).rejects.toThrow(NotFoundException);
    });
  });

  describe('updateProfile', () => {
    it('should update and return user', async () => {
      const user = { id: 1, nickname: 'old' };
      userRepo.findOne.mockResolvedValue(user);
      userRepo.save.mockResolvedValue({ ...user, nickname: 'new' });

      const result = await service.updateProfile(1, { nickname: 'new' });

      expect(result.nickname).toBe('new');
      expect(userRepo.save).toHaveBeenCalled();
    });

    it('should throw NotFoundException when user not found', async () => {
      userRepo.findOne.mockResolvedValue(null);

      await expect(service.updateProfile(999, { nickname: 'x' })).rejects.toThrow(
        NotFoundException,
      );
    });
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:unit -- src/modules/user/user.service.spec.ts
```

Expected: 4 passed

- [ ] **Step 3: Commit**

```bash
git add packages/server/src/modules/user/user.service.spec.ts
git commit -m "test(user): user.service 单测覆盖 getProfile/updateProfile"
```

---

## Task 2: cart.service.spec.ts

**Files:**

- Create: `packages/server/src/modules/cart/cart.service.spec.ts`
- Source: `packages/server/src/modules/cart/cart.service.ts`

- [ ] **Step 1: 写 spec 文件**

```typescript
import { NotFoundException } from '@nestjs/common';
import { CartService } from './cart.service';

describe('CartService', () => {
  let service: CartService;
  let cartRepo: any;
  let productRepo: any;
  let dataSource: any;

  beforeEach(() => {
    cartRepo = {
      find: jest.fn(),
      findOne: jest.fn(),
      create: jest.fn((x) => x),
      save: jest.fn(),
      remove: jest.fn(),
      createQueryBuilder: jest.fn(),
    };
    productRepo = { findOne: jest.fn() };
    dataSource = {};
    service = new CartService(cartRepo, productRepo, dataSource);
  });

  describe('findAll', () => {
    it('should map fields and handle null product', async () => {
      cartRepo.find.mockResolvedValue([
        {
          id: 1,
          userId: 10,
          productId: 100,
          specLabel: '1kg',
          quantity: 2,
          createdAt: new Date(),
          updatedAt: new Date(),
          product: {
            id: 100,
            name: 'Apple',
            price: 9.9,
            originalPrice: 12,
            image: 'i',
            unit: '斤',
            stock: 50,
            status: 1,
          },
        },
        {
          id: 2,
          userId: 10,
          productId: 200,
          specLabel: '2kg',
          quantity: 1,
          createdAt: new Date(),
          updatedAt: new Date(),
          product: null,
        },
      ]);

      const result = await service.findAll(10);

      expect(result).toHaveLength(2);
      expect(result[0].product).toMatchObject({ id: 100, name: 'Apple' });
      expect(result[1].product).toBeNull();
    });
  });

  describe('add', () => {
    it('should throw NotFound when product missing', async () => {
      productRepo.findOne.mockResolvedValue(null);
      await expect(service.add(10, { productId: 999, specLabel: '1kg' })).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should merge quantity when item exists', async () => {
      productRepo.findOne.mockResolvedValue({ id: 1 });
      const existing = { id: 5, userId: 10, productId: 1, specLabel: '1kg', quantity: 2 };
      cartRepo.findOne.mockResolvedValue(existing);
      cartRepo.find.mockResolvedValue([]);

      await service.add(10, { productId: 1, specLabel: '1kg', quantity: 3 });

      expect(existing.quantity).toBe(5);
      expect(cartRepo.save).toHaveBeenCalledWith(existing);
    });

    it('should create new item when not exists, default quantity 1', async () => {
      productRepo.findOne.mockResolvedValue({ id: 1 });
      cartRepo.findOne.mockResolvedValue(null);
      cartRepo.create.mockImplementation((x) => x);
      cartRepo.find.mockResolvedValue([]);

      await service.add(10, { productId: 1, specLabel: '1kg' });

      expect(cartRepo.create).toHaveBeenCalledWith(expect.objectContaining({ quantity: 1 }));
    });
  });

  describe('update', () => {
    it('should throw NotFound when item missing', async () => {
      cartRepo.findOne.mockResolvedValue(null);
      await expect(service.update(1, 10, { quantity: 3 })).rejects.toThrow(NotFoundException);
    });

    it('should update quantity', async () => {
      const item = { id: 1, userId: 10, quantity: 2 };
      cartRepo.findOne.mockResolvedValue(item);
      cartRepo.find.mockResolvedValue([]);
      await service.update(1, 10, { quantity: 5 });
      expect(item.quantity).toBe(5);
      expect(cartRepo.save).toHaveBeenCalledWith(item);
    });
  });

  describe('remove', () => {
    it('should throw NotFound when item missing', async () => {
      cartRepo.findOne.mockResolvedValue(null);
      await expect(service.remove(1, 10)).rejects.toThrow(NotFoundException);
    });

    it('should call remove', async () => {
      const item = { id: 1, userId: 10 };
      cartRepo.findOne.mockResolvedValue(item);
      cartRepo.find.mockResolvedValue([]);
      await service.remove(1, 10);
      expect(cartRepo.remove).toHaveBeenCalledWith(item);
    });
  });

  describe('removeByUserAndProductIds', () => {
    it('should noop when productIds empty', async () => {
      await service.removeByUserAndProductIds(10, []);
      expect(cartRepo.createQueryBuilder).not.toHaveBeenCalled();
    });

    it('should execute delete when non-empty', async () => {
      const execute = jest.fn();
      const qb = {
        delete: jest.fn().mockReturnThis(),
        from: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        execute,
      };
      cartRepo.createQueryBuilder.mockReturnValue(qb);
      await service.removeByUserAndProductIds(10, [1, 2]);
      expect(execute).toHaveBeenCalled();
    });
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:unit -- src/modules/cart/cart.service.spec.ts
```

Expected: 9 passed

- [ ] **Step 3: Commit**

```bash
git add packages/server/src/modules/cart/cart.service.spec.ts
git commit -m "test(cart): cart.service 单测覆盖 add/update/remove/find/批量删"
```

---

## Task 3: product.service.spec.ts

**Files:**

- Create: `packages/server/src/modules/product/product.service.spec.ts`
- Source: `packages/server/src/modules/product/product.service.ts`

- [ ] **Step 1: 写 spec 文件**

```typescript
import { NotFoundException } from '@nestjs/common';
import { ProductService } from './product.service';

describe('ProductService', () => {
  let service: ProductService;
  let productRepo: any;
  let categoryRepo: any;
  let redis: any;

  beforeEach(() => {
    const qbChain = {
      andWhere: jest.fn().mockReturnThis(),
      getCount: jest.fn(),
      orderBy: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getMany: jest.fn(),
    };
    productRepo = {
      createQueryBuilder: jest.fn(() => qbChain),
      findOne: jest.fn(),
      create: jest.fn((x) => x),
      save: jest.fn(),
      remove: jest.fn(),
    };
    categoryRepo = { find: jest.fn() };
    redis = { get: jest.fn(), set: jest.fn(), keys: jest.fn(), del: jest.fn() };
    service = new ProductService(productRepo, categoryRepo, redis);
    // 暴露 qbChain 便于每用例重设
    (service as any).__qb = qbChain;
  });

  describe('findAll', () => {
    it('should return cached when hit', async () => {
      const cached = { list: [{ id: 1 }], total: 1, page: 1, limit: 10 };
      redis.get.mockResolvedValue(JSON.stringify(cached));

      const result = await service.findAll({ page: 1, limit: 10 });

      expect(result).toEqual(cached);
      expect(productRepo.createQueryBuilder).not.toHaveBeenCalled();
    });

    it('should query DB and write cache when miss', async () => {
      redis.get.mockResolvedValue(null);
      const qb = (service as any).__qb;
      qb.getCount.mockResolvedValue(1);
      qb.getMany.mockResolvedValue([{ id: 1 }]);

      const result = await service.findAll({ page: 1, limit: 10 });

      expect(result.total).toBe(1);
      expect(redis.set).toHaveBeenCalledWith(
        expect.stringMatching(/^products:/),
        expect.any(String),
        'EX',
        60,
      );
    });

    it('should apply categoryId filter', async () => {
      redis.get.mockResolvedValue(null);
      const qb = (service as any).__qb;
      qb.getCount.mockResolvedValue(0);
      qb.getMany.mockResolvedValue([]);
      await service.findAll({ categoryId: 5, page: 1, limit: 10 });
      expect(qb.andWhere).toHaveBeenCalledWith('p.category_id = :categoryId', { categoryId: 5 });
    });

    it('should apply keyword filter', async () => {
      redis.get.mockResolvedValue(null);
      const qb = (service as any).__qb;
      qb.getCount.mockResolvedValue(0);
      qb.getMany.mockResolvedValue([]);
      await service.findAll({ keyword: '苹', page: 1, limit: 10 });
      expect(qb.andWhere).toHaveBeenCalledWith('p.name LIKE :keyword', { keyword: '%苹%' });
    });
  });

  describe('findOne', () => {
    it('should return cached', async () => {
      redis.get.mockResolvedValue(JSON.stringify({ id: 1 }));
      const result = await service.findOne(1);
      expect(result.id).toBe(1);
      expect(productRepo.findOne).not.toHaveBeenCalled();
    });

    it('should throw NotFound when not found', async () => {
      redis.get.mockResolvedValue(null);
      productRepo.findOne.mockResolvedValue(null);
      await expect(service.findOne(999)).rejects.toThrow(NotFoundException);
    });

    it('should write cache when found', async () => {
      redis.get.mockResolvedValue(null);
      const p = { id: 1, name: 'A' };
      productRepo.findOne.mockResolvedValue(p);
      await service.findOne(1);
      expect(redis.set).toHaveBeenCalledWith('product:1', expect.any(String), 'EX', 60);
    });
  });

  describe('create', () => {
    it('should save and clear cache', async () => {
      productRepo.save.mockResolvedValue({ id: 1 });
      redis.keys.mockResolvedValue(['products:a']);
      await service.create({ name: 'A', price: 1 } as any);
      expect(productRepo.save).toHaveBeenCalled();
      expect(redis.del).toHaveBeenCalledWith('products:a');
    });
  });

  describe('update', () => {
    it('should throw NotFound', async () => {
      productRepo.findOne.mockResolvedValue(null);
      await expect(service.update(999, { name: 'x' } as any)).rejects.toThrow(NotFoundException);
    });

    it('should update and clear caches', async () => {
      const p = { id: 1, name: 'A' };
      productRepo.findOne.mockResolvedValue(p);
      productRepo.save.mockResolvedValue({ ...p, name: 'B' });
      redis.keys.mockResolvedValue(['products:a']);
      await service.update(1, { name: 'B' } as any);
      expect(redis.del).toHaveBeenCalledWith('products:a');
      expect(redis.del).toHaveBeenCalledWith('product:1');
    });
  });

  describe('remove', () => {
    it('should throw NotFound', async () => {
      productRepo.findOne.mockResolvedValue(null);
      await expect(service.remove(999)).rejects.toThrow(NotFoundException);
    });

    it('should remove and clear caches', async () => {
      const p = { id: 1 };
      productRepo.findOne.mockResolvedValue(p);
      redis.keys.mockResolvedValue(['products:a']);
      await service.remove(1);
      expect(productRepo.remove).toHaveBeenCalledWith(p);
      expect(redis.del).toHaveBeenCalledWith('product:1');
    });
  });

  describe('findAllCategories', () => {
    it('should return cached', async () => {
      redis.get.mockResolvedValue(JSON.stringify([{ id: 1 }]));
      const r = await service.findAllCategories();
      expect(r).toEqual([{ id: 1 }]);
      expect(categoryRepo.find).not.toHaveBeenCalled();
    });

    it('should query and cache 300s', async () => {
      redis.get.mockResolvedValue(null);
      categoryRepo.find.mockResolvedValue([{ id: 1 }]);
      await service.findAllCategories();
      expect(redis.set).toHaveBeenCalledWith('categories:all', expect.any(String), 'EX', 300);
    });
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:unit -- src/modules/product/product.service.spec.ts
```

Expected: 12 passed

- [ ] **Step 3: Commit**

```bash
git add packages/server/src/modules/product/product.service.spec.ts
git commit -m "test(product): product.service 单测覆盖缓存/CRUD/分类"
```

---

## Task 4: order.service.spec.ts（含事务 mock）

**Files:**

- Create: `packages/server/src/modules/order/order.service.spec.ts`
- Source: `packages/server/src/modules/order/order.service.ts`

- [ ] **Step 1: 写 spec 文件**

```typescript
import { NotFoundException, BadRequestException } from '@nestjs/common';
import { OrderService } from './order.service';

describe('OrderService', () => {
  let service: OrderService;
  let orderRepo: any;
  let orderItemRepo: any;
  let cartRepo: any;
  let cartService: any;
  let dataSource: any;
  let queryRunner: any;
  let logger: any;

  beforeEach(() => {
    const execute = jest.fn();
    const deleteQb = {
      delete: jest.fn().mockReturnThis(),
      from: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      execute,
    };
    queryRunner = {
      connect: jest.fn(),
      startTransaction: jest.fn(),
      manager: {
        create: jest.fn((_, x) => x),
        save: jest.fn(),
        createQueryBuilder: jest.fn(() => deleteQb),
      },
      commitTransaction: jest.fn(),
      rollbackTransaction: jest.fn(),
      release: jest.fn(),
    };
    dataSource = { createQueryRunner: jest.fn(() => queryRunner) };
    orderRepo = { createQueryBuilder: jest.fn(), findOne: jest.fn() };
    orderItemRepo = { find: jest.fn() };
    cartRepo = { find: jest.fn() };
    cartService = {};
    logger = { setContext: jest.fn(), info: jest.fn() };
    service = new OrderService(orderRepo, orderItemRepo, cartRepo, cartService, dataSource, logger);
  });

  describe('create', () => {
    it('should throw BadRequest when cart empty', async () => {
      cartRepo.find.mockResolvedValue([]);
      await expect(service.create(1, { address: 'a', phone: 'p' } as any)).rejects.toThrow(
        BadRequestException,
      );
      expect(dataSource.createQueryRunner).not.toHaveBeenCalled();
    });

    it('should compute totalAmount and commit in order', async () => {
      cartRepo.find.mockResolvedValue([
        {
          productId: 1,
          specLabel: '1kg',
          quantity: 2,
          product: { id: 1, name: 'A', price: '9.9', image: 'i' },
        },
        {
          productId: 2,
          specLabel: '2kg',
          quantity: 1,
          product: { id: 2, name: 'B', price: '5', image: 'j' },
        },
      ]);
      queryRunner.manager.save.mockResolvedValueOnce({ id: 100 } as any); // savedOrder
      orderRepo.createQueryBuilder.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        getOne: jest.fn().mockResolvedValue({ id: 100 }),
      });
      orderItemRepo.find.mockResolvedValue([{ id: 1, orderId: 100 }]);

      const result = await service.create(1, { address: 'a', phone: 'p' } as any);

      // totalAmount = 9.9*2 + 5*1 = 24.8
      expect(queryRunner.manager.save).toHaveBeenNthCalledWith(
        1,
        expect.anything(),
        expect.objectContaining({ totalAmount: 24.8 }),
      );
      expect(queryRunner.commitTransaction).toHaveBeenCalled();
      expect(queryRunner.rollbackTransaction).not.toHaveBeenCalled();
      expect(queryRunner.release).toHaveBeenCalled();
    });

    it('should rollback and rethrow on save error', async () => {
      cartRepo.find.mockResolvedValue([
        { productId: 1, quantity: 1, product: { price: '1', name: 'A', image: 'i' } },
      ]);
      queryRunner.manager.save.mockRejectedValue(new Error('db down'));

      await expect(service.create(1, { address: 'a', phone: 'p' } as any)).rejects.toThrow(
        'db down',
      );

      expect(queryRunner.rollbackTransaction).toHaveBeenCalled();
      expect(queryRunner.commitTransaction).not.toHaveBeenCalled();
      expect(queryRunner.release).toHaveBeenCalled();
    });
  });

  describe('findAll', () => {
    it('should apply status filter', async () => {
      const qb = {
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        getCount: jest.fn().mockResolvedValue(0),
        orderBy: jest.fn().mockReturnThis(),
        skip: jest.fn().mockReturnThis(),
        take: jest.fn().mockReturnThis(),
        getMany: jest.fn().mockResolvedValue([]),
      };
      orderRepo.createQueryBuilder.mockReturnValue(qb);
      const r = await service.findAll(1, { status: 1, page: 2, limit: 5 });
      expect(qb.andWhere).toHaveBeenCalledWith('o.status = :status', { status: 1 });
      expect(qb.skip).toHaveBeenCalledWith(5);
      expect(qb.take).toHaveBeenCalledWith(5);
      expect(r.page).toBe(2);
    });

    it('should default page/limit', async () => {
      const qb = {
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        getCount: jest.fn().mockResolvedValue(0),
        orderBy: jest.fn().mockReturnThis(),
        skip: jest.fn().mockReturnThis(),
        take: jest.fn().mockReturnThis(),
        getMany: jest.fn().mockResolvedValue([]),
      };
      orderRepo.createQueryBuilder.mockReturnValue(qb);
      const r = await service.findAll(1, {});
      expect(qb.skip).toHaveBeenCalledWith(0);
      expect(qb.take).toHaveBeenCalledWith(10);
    });
  });

  describe('findOne', () => {
    it('should throw NotFound when order missing', async () => {
      orderRepo.findOne.mockResolvedValue(null);
      await expect(service.findOne(1, 999)).rejects.toThrow(NotFoundException);
    });

    it('should return order with items', async () => {
      orderRepo.findOne.mockResolvedValue({ id: 1 });
      orderItemRepo.find.mockResolvedValue([{ id: 1 }]);
      const r = await service.findOne(1, 1);
      expect(r.items).toEqual([{ id: 1 }]);
    });
  });

  describe('cancel', () => {
    it('should throw NotFound when order missing', async () => {
      orderRepo.findOne.mockResolvedValue(null);
      await expect(service.cancel(1, 999)).rejects.toThrow(NotFoundException);
    });

    it('should throw BadRequest when not PENDING', async () => {
      orderRepo.findOne.mockResolvedValue({ id: 1, status: 2 }); // 2=PAID 非 PENDING
      await expect(service.cancel(1, 1)).rejects.toThrow(BadRequestException);
    });

    it('should update status to CANCELLED', async () => {
      const order = { id: 1, status: 1 }; // PENDING
      orderRepo.findOne.mockResolvedValue(order);
      orderItemRepo.find.mockResolvedValue([]);
      await service.cancel(1, 1);
      expect(order.status).toBe(4); // CANCELLED
      expect(orderRepo.save).not.toHaveBeenCalled(); // save 通过 orderRepo.save — 检查 mock 已 set
      // 注：service.cancel 用 orderRepo.save，需在 beforeEach 加
    });
  });
});
```

**重要修正**：`orderRepo` 在 `cancel` 用了 `orderRepo.save`，需在 `beforeEach` 中补 `save: jest.fn()`。在 Step 1 文件中实际写入时加上。

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:unit -- src/modules/order/order.service.spec.ts
```

Expected: 10 passed

- [ ] **Step 3: Commit**

```bash
git add packages/server/src/modules/order/order.service.spec.ts
git commit -m "test(order): order.service 单测覆盖事务/取消/查询"
```

---

## Task 5: auth.service.spec.ts

**Files:**

- Create: `packages/server/src/modules/auth/auth.service.spec.ts`
- Source: `packages/server/src/modules/auth/auth.service.ts`

- [ ] **Step 1: 写 spec 文件**

```typescript
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { AuthService } from './auth.service';

// Mock bcryptjs
jest.mock('bcryptjs');
const mockedBcrypt = bcrypt as jest.Mocked<typeof bcrypt>;

// Mock uuid (固定 jti 便于断言)
jest.mock('uuid', () => ({
  v4: jest.fn(() => 'fixed-jti'),
}));

describe('AuthService', () => {
  let service: AuthService;
  let userRepo: any;
  let jwtService: any;
  let configService: any;
  let redis: any;
  let logger: any;

  beforeEach(() => {
    userRepo = { findOne: jest.fn(), count: jest.fn(), create: jest.fn((x) => x), save: jest.fn() };
    jwtService = { sign: jest.fn(), verify: jest.fn(), decode: jest.fn() };
    configService = {
      get: jest.fn((k: string) => {
        if (k === 'JWT_SECRET') return 'test-secret';
        if (k === 'JWT_ACCESS_EXPIRES_IN') return '900';
        if (k === 'JWT_REFRESH_EXPIRES_IN') return '604800';
        return undefined;
      }),
    };
    redis = { get: jest.fn(), set: jest.fn() };
    logger = {
      setContext: jest.fn(),
      info: jest.fn(),
      warn: jest.fn(),
      error: jest.fn(),
      debug: jest.fn(),
    };
    service = new AuthService(userRepo, jwtService, configService, redis, logger);
    jest.clearAllMocks();
  });

  describe('register', () => {
    it('should set ADMIN for first user', async () => {
      userRepo.findOne.mockResolvedValue(null); // 手机号未注册
      userRepo.count.mockResolvedValue(0);
      mockedBcrypt.hash.mockResolvedValue('hashed' as never);
      jwtService.sign.mockReturnValue('token');
      userRepo.save.mockResolvedValue({ id: 1, phone: 'p', role: 'admin' });

      const result = await service.register({ phone: '13800000001', password: 'pass1234' });

      expect(userRepo.create).toHaveBeenCalledWith(expect.objectContaining({ role: 'admin' }));
      expect(result.user.role).toBe('admin');
      expect(result.accessToken).toBe('token');
    });

    it('should set USER for non-first user', async () => {
      userRepo.findOne.mockResolvedValue(null);
      userRepo.count.mockResolvedValue(5);
      mockedBcrypt.hash.mockResolvedValue('hashed' as never);
      jwtService.sign.mockReturnValue('token');
      userRepo.save.mockResolvedValue({ id: 2, phone: 'p', role: 'user' });

      const result = await service.register({ phone: '13800000002', password: 'pass1234' });

      expect(userRepo.create).toHaveBeenCalledWith(expect.objectContaining({ role: 'user' }));
    });

    it('should throw Conflict when phone exists', async () => {
      userRepo.findOne.mockResolvedValue({ id: 1 });
      await expect(
        service.register({ phone: '13800000001', password: 'pass1234' }),
      ).rejects.toThrow(ConflictException);
    });

    it('should hash password with salt 10', async () => {
      userRepo.findOne.mockResolvedValue(null);
      userRepo.count.mockResolvedValue(0);
      mockedBcrypt.hash.mockResolvedValue('hashed' as never);
      jwtService.sign.mockReturnValue('token');
      userRepo.save.mockResolvedValue({ id: 1, phone: 'p', role: 'admin' });
      await service.register({ phone: '13800000001', password: 'pass1234' });
      expect(mockedBcrypt.hash).toHaveBeenCalledWith('pass1234', 10);
    });
  });

  describe('login', () => {
    const buildQb = (user: any) => ({
      addSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      getOne: jest.fn().mockResolvedValue(user),
    });

    it('should throw Unauthorized when user not found', async () => {
      userRepo.createQueryBuilder = jest.fn(() => buildQb(null));
      await expect(service.login({ phone: 'p', password: 'x' })).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('should throw Unauthorized when password wrong', async () => {
      userRepo.createQueryBuilder = jest.fn(() =>
        buildQb({ id: 1, phone: 'p', password: 'hashed', role: 'user' }),
      );
      mockedBcrypt.compare.mockResolvedValue(false as never);
      await expect(service.login({ phone: 'p', password: 'wrong' })).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('should return tokens and user on success', async () => {
      userRepo.createQueryBuilder = jest.fn(() =>
        buildQb({ id: 1, phone: 'p', password: 'hashed', role: 'user' }),
      );
      mockedBcrypt.compare.mockResolvedValue(true as never);
      jwtService.sign.mockReturnValue('token');

      const result = await service.login({ phone: 'p', password: 'pass' });

      expect(result.accessToken).toBe('token');
      expect(result.refreshToken).toBe('token');
      expect(result.user).not.toHaveProperty('password');
    });
  });

  describe('refresh', () => {
    it('should throw when token type is not refresh', async () => {
      jwtService.verify.mockReturnValue({ sub: 1, type: 'access', jti: 'j' });
      await expect(service.refresh({ refreshToken: 't' })).rejects.toThrow(UnauthorizedException);
    });

    it('should throw when blacklisted', async () => {
      jwtService.verify.mockReturnValue({ sub: 1, type: 'refresh', jti: 'j' });
      redis.get.mockResolvedValue('1');
      await expect(service.refresh({ refreshToken: 't' })).rejects.toThrow(UnauthorizedException);
    });

    it('should throw when user not found', async () => {
      jwtService.verify.mockReturnValue({ sub: 1, type: 'refresh', jti: 'j' });
      redis.get.mockResolvedValue(null);
      userRepo.findOne.mockResolvedValue(null);
      await expect(service.refresh({ refreshToken: 't' })).rejects.toThrow(UnauthorizedException);
    });

    it('should throw when jwt.verify fails (expired)', async () => {
      jwtService.verify.mockImplementation(() => {
        throw new Error('expired');
      });
      await expect(service.refresh({ refreshToken: 't' })).rejects.toThrow(UnauthorizedException);
    });

    it('should return new accessToken on success', async () => {
      jwtService.verify.mockReturnValue({ sub: 1, type: 'refresh', jti: 'j' });
      redis.get.mockResolvedValue(null);
      userRepo.findOne.mockResolvedValue({ id: 1, phone: 'p', role: 'user' });
      jwtService.sign.mockReturnValue('new-at');

      const result = await service.refresh({ refreshToken: 't' });

      expect(result.accessToken).toBe('new-at');
    });
  });

  describe('logout', () => {
    it('should write blacklist with TTL when decode ok', async () => {
      const futureExp = Math.floor(Date.now() / 1000) + 3600;
      jwtService.decode.mockReturnValue({ exp: futureExp, jti: 'abc' });

      await service.logout(1, 'abc', 'Bearer t');

      expect(redis.set).toHaveBeenCalledWith('token:blacklist:abc', '1', 'EX', expect.any(Number));
    });

    it('should noop when decode returns null', async () => {
      jwtService.decode.mockReturnValue(null);
      await service.logout(1, 'abc', 't');
      expect(redis.set).not.toHaveBeenCalled();
    });

    it('should noop when ttl <= 0', async () => {
      const pastExp = Math.floor(Date.now() / 1000) - 100;
      jwtService.decode.mockReturnValue({ exp: pastExp });
      await service.logout(1, 'abc', 't');
      expect(redis.set).not.toHaveBeenCalled();
    });

    it('should swallow decode error silently', async () => {
      jwtService.decode.mockImplementation(() => {
        throw new Error('decode fail');
      });
      const r = await service.logout(1, 'abc', 't');
      expect(r).toBeNull();
    });
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:unit -- src/modules/auth/auth.service.spec.ts
```

Expected: 14 passed

- [ ] **Step 3: Commit**

```bash
git add packages/server/src/modules/auth/auth.service.spec.ts
git commit -m "test(auth): auth.service 单测覆盖 register/login/refresh/logout"
```

---

## Task 6: jwt.strategy.spec.ts

**Files:**

- Create: `packages/server/src/modules/auth/jwt.strategy.spec.ts`
- Source: `packages/server/src/modules/auth/jwt.strategy.ts`

- [ ] **Step 1: 写 spec 文件**

```typescript
import { UnauthorizedException } from '@nestjs/common';
import { JwtStrategy } from './jwt.strategy';

// 直接实例化绕过 PassportStrategy super 的 secretOrKey 校验
describe('JwtStrategy.validate', () => {
  let strategy: any;
  let redis: any;

  beforeAll(() => {
    const configService: any = { get: jest.fn(() => 'secret') };
    redis = { get: jest.fn() };
    // 用 Object.create 绕过 super 构造
    strategy = Object.create(JwtStrategy.prototype);
    strategy.configService = configService;
    strategy.redis = redis;
  });

  it('should throw TOKEN_INVALID when type is not access', async () => {
    await expect(
      strategy.validate({ sub: 1, phone: 'p', role: 'user', jti: 'j', type: 'refresh' }),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('should throw TOKEN_EXPIRED when blacklisted', async () => {
    redis.get.mockResolvedValue('1');
    await expect(
      strategy.validate({ sub: 1, phone: 'p', role: 'user', jti: 'j', type: 'access' }),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('should return payload when valid', async () => {
    redis.get.mockResolvedValue(null);
    const result = await strategy.validate({
      sub: 1,
      phone: 'p',
      role: 'user',
      jti: 'j',
      type: 'access',
    });
    expect(result).toEqual({ id: 1, phone: 'p', role: 'user', jti: 'j' });
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:unit -- src/modules/auth/jwt.strategy.spec.ts
```

Expected: 3 passed

- [ ] **Step 3: Commit**

```bash
git add packages/server/src/modules/auth/jwt.strategy.spec.ts
git commit -m "test(auth): jwt.strategy.validate 单测覆盖类型/黑名单"
```

---

## Task 7: jwt-auth.guard.spec.ts

**Files:**

- Create: `packages/server/src/common/guards/jwt-auth.guard.spec.ts`
- Source: `packages/server/src/common/guards/jwt-auth.guard.ts`

- [ ] **Step 1: 写 spec 文件**

```typescript
import { Reflector } from '@nestjs/core';
import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { JwtAuthGuard } from './jwt-auth.guard';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

describe('JwtAuthGuard', () => {
  let guard: JwtAuthGuard;
  let reflector: jest.Mocked<Reflector>;

  beforeEach(() => {
    reflector = { getAllAndOverride: jest.fn() } as any;
    guard = new JwtAuthGuard(reflector);
    // super.canActivate 默认抛错，mock 掉
    (guard as any).canActivate = JwtAuthGuard.prototype.canActivate;
    jest
      .spyOn(Object.getPrototypeOf(Object.getPrototypeOf(guard)), 'canActivate')
      .mockReturnValue(true);
  });

  const mockCtx = (handler: any, clazz: any): ExecutionContext =>
    ({ getHandler: () => handler, getClass: () => clazz }) as any;

  it('should return true when @Public', () => {
    reflector.getAllAndOverride.mockReturnValue(true);
    const ctx = mockCtx(() => {}, class T {});
    expect(guard.canActivate(ctx)).toBe(true);
  });

  it('should call super.canActivate when not @Public', () => {
    reflector.getAllAndOverride.mockReturnValue(false);
    const ctx = mockCtx(() => {}, class T {});
    expect(guard.canActivate(ctx)).toBe(true); // super mock 返回 true
  });

  describe('handleRequest', () => {
    it('should rethrow err', () => {
      const err = new Error('boom');
      expect(() => guard.handleRequest(err, false, null)).toThrow(err);
    });

    it('should throw UnauthorizedException when no user no err', () => {
      expect(() => guard.handleRequest(null, false, null)).toThrow(UnauthorizedException);
    });

    it('should return user when valid', () => {
      const user = { id: 1 };
      expect(guard.handleRequest(null, user, null)).toBe(user);
    });
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:unit -- src/common/guards/jwt-auth.guard.spec.ts
```

Expected: 5 passed

- [ ] **Step 3: Commit**

```bash
git add packages/server/src/common/guards/jwt-auth.guard.spec.ts
git commit -m "test(common): jwt-auth.guard 单测覆盖 @Public/handleRequest"
```

---

## Task 8: roles.guard.spec.ts

**Files:**

- Create: `packages/server/src/common/guards/roles.guard.spec.ts`
- Source: `packages/server/src/common/guards/roles.guard.ts`

- [ ] **Step 1: 写 spec 文件**

```typescript
import { Reflector } from '@nestjs/core';
import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { RolesGuard } from './roles.guard';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { UserRole } from 'shared';

describe('RolesGuard', () => {
  let guard: RolesGuard;
  let reflector: jest.Mocked<Reflector>;

  beforeEach(() => {
    reflector = { getAllAndOverride: jest.fn() } as any;
    guard = new RolesGuard(reflector);
  });

  const ctx = (user: any) =>
    ({
      getHandler: () => ({}),
      getClass: () => ({}),
      switchToHttp: () => ({ getRequest: () => ({ user }) }),
    }) as any;

  it('should return true when no @Roles', () => {
    reflector.getAllAndOverride.mockReturnValue(undefined);
    expect(guard.canActivate(ctx({}))).toBe(true);
  });

  it('should return false when user is null', () => {
    reflector.getAllAndOverride.mockReturnValue([UserRole.ADMIN]);
    expect(guard.canActivate(ctx(null))).toBe(false);
  });

  it('should return true when role matches', () => {
    reflector.getAllAndOverride.mockReturnValue([UserRole.ADMIN]);
    expect(guard.canActivate(ctx({ role: UserRole.ADMIN }))).toBe(true);
  });

  it('should throw ForbiddenException when role mismatch', () => {
    reflector.getAllAndOverride.mockReturnValue([UserRole.ADMIN]);
    expect(() => guard.canActivate(ctx({ role: UserRole.USER }))).toThrow(ForbiddenException);
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:unit -- src/common/guards/roles.guard.spec.ts
```

Expected: 4 passed

- [ ] **Step 3: Commit**

```bash
git add packages/server/src/common/guards/roles.guard.spec.ts
git commit -m "test(common): roles.guard 单测覆盖角色匹配/缺失"
```

---

## Task 9: transform.interceptor.spec.ts

**Files:**

- Create: `packages/server/src/common/interceptors/transform.interceptor.spec.ts`
- Source: `packages/server/src/common/interceptors/transform.interceptor.ts`

- [ ] **Step 1: 写 spec 文件**

```typescript
import { Reflector } from '@nestjs/core';
import { of } from 'rxjs';
import { TransformInterceptor, SKIP_TRANSFORM_KEY } from './transform.interceptor';

describe('TransformInterceptor', () => {
  let reflector: jest.Mocked<Reflector>;
  let interceptor: TransformInterceptor<any>;
  const ctx: any = { getHandler: () => ({}) };

  const callWith = (data: any) => interceptor.intercept(ctx, { handle: () => of(data) } as any);

  it('should wrap response when no SKIP_TRANSFORM', (done) => {
    reflector = { get: jest.fn().mockReturnValue(undefined) } as any;
    interceptor = new TransformInterceptor(reflector);
    callWith({ a: 1 }).subscribe((r: any) => {
      expect(r).toEqual({ code: 0, data: { a: 1 }, message: 'success' });
      done();
    });
  });

  it('should pass through when SKIP_TRANSFORM', (done) => {
    reflector = { get: jest.fn().mockReturnValue(true) } as any;
    interceptor = new TransformInterceptor(reflector);
    callWith({ raw: 1 }).subscribe((r: any) => {
      expect(r).toEqual({ raw: 1 });
      done();
    });
  });

  it('should wrap when reflector is undefined (optional)', (done) => {
    interceptor = new TransformInterceptor(undefined as any);
    callWith({ a: 1 }).subscribe((r: any) => {
      expect(r).toEqual({ code: 0, data: { a: 1 }, message: 'success' });
      done();
    });
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:unit -- src/common/interceptors/transform.interceptor.spec.ts
```

Expected: 3 passed

- [ ] **Step 3: Commit**

```bash
git add packages/server/src/common/interceptors/transform.interceptor.spec.ts
git commit -m "test(common): transform.interceptor 单测覆盖包装/透传"
```

---

## Task 10: http-exception.filter.spec.ts

**Files:**

- Create: `packages/server/src/common/filters/http-exception.filter.spec.ts`
- Source: `packages/server/src/common/filters/http-exception.filter.ts`

- [ ] **Step 1: 写 spec 文件**

```typescript
import { HttpException, HttpStatus, ServiceUnavailableException } from '@nestjs/common';
import { ThrottlerException } from '@nestjs/throttler';
import { HttpExceptionFilter } from './http-exception.filter';

describe('HttpExceptionFilter', () => {
  let filter: HttpExceptionFilter;
  let logger: any;
  let response: any;
  let host: any;

  beforeEach(() => {
    logger = { warn: jest.fn(), error: jest.fn() };
    filter = new HttpExceptionFilter(logger);
    response = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    host = {
      switchToHttp: () => ({
        getRequest: () => ({ method: 'POST', url: '/api/x' }),
        getResponse: () => response,
      }),
    } as any;
  });

  it('should pass through business code', () => {
    filter.catch(
      new HttpException({ code: 40001, message: 'phone exists' }, HttpStatus.CONFLICT),
      host,
    );
    expect(response.json).toHaveBeenCalledWith({ code: 40001, message: 'phone exists' });
    expect(response.status).toHaveBeenCalledWith(HttpStatus.OK);
  });

  it('should join class-validator array messages', () => {
    filter.catch(
      new HttpException(
        { message: ['phone invalid', 'password short'], error: 'Bad Request', statusCode: 400 },
        HttpStatus.BAD_REQUEST,
      ),
      host,
    );
    const args = response.json.mock.calls[0][0];
    expect(args.code).toBe(400);
    expect(args.message).toContain('; ');
  });

  it('should use string response directly', () => {
    filter.catch(new HttpException('plain msg', HttpStatus.BAD_REQUEST), host);
    expect(response.json).toHaveBeenCalledWith({ code: 400, message: 'plain msg' });
  });

  it('should fallback to status code for plain HttpException', () => {
    filter.catch(new HttpException('not found', HttpStatus.NOT_FOUND), host);
    expect(response.json).toHaveBeenCalledWith({ code: 404, message: 'not found' });
  });

  it('should return 429 for ThrottlerException', () => {
    filter.catch(new ThrottlerException(), host);
    expect(response.status).toHaveBeenCalledWith(HttpStatus.TOO_MANY_REQUESTS);
    const args = response.json.mock.calls[0][0];
    expect(args.code).toBe(429);
    expect(args.message).toBe('Too Many Requests');
  });

  it('should pass through terminus body on ServiceUnavailableException', () => {
    const terminusBody = { status: 'error', details: { db: { status: 'down' } } };
    filter.catch(new ServiceUnavailableException({ response: terminusBody }), host);
    expect(response.status).toHaveBeenCalledWith(HttpStatus.SERVICE_UNAVAILABLE);
    expect(response.json).toHaveBeenCalledWith(terminusBody);
  });

  it('should log error and return 500 on unknown exception', () => {
    filter.catch(new Error('boom'), host);
    expect(logger.error).toHaveBeenCalled();
    expect(response.json).toHaveBeenCalledWith({ code: 500, message: '服务器内部错误' });
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:unit -- src/common/filters/http-exception.filter.spec.ts
```

Expected: 7 passed

- [ ] **Step 3: Commit**

```bash
git add packages/server/src/common/filters/http-exception.filter.spec.ts
git commit -m "test(common): http-exception.filter 单测覆盖各类异常分支"
```

---

## Task 11: 跑全套单测验证

**Files:** 无新增

- [ ] **Step 1: 跑全部 unit**

```bash
pnpm --filter server test:unit
```

Expected: 所有单测（含原有 controller spec + 10 个新增 spec）PASS

- [ ] **Step 2: 若有失败，定位修复**（仅测试代码层）

记录失败原因，修正 mock 或断言，重跑直到全绿。

---

## Task 12: TestHelper 扩展

**Files:**

- Modify: `packages/server/test/helpers/test-helper.ts`（在类末尾追加方法）

- [ ] **Step 1: 追加助手方法**

在 `registerAdmin` 方法之后追加：

```typescript
  /**
   * 以 admin 身份创建商品，返回新商品 id
   */
  async createProductAsAdmin(
    token: string,
    overrides: Record<string, any> = {},
  ): Promise<number> {
    const body = {
      name: overrides.name ?? `测试商品-${Date.now()}`,
      origin: overrides.origin ?? '测试产地',
      price: overrides.price ?? 19.9,
      unit: overrides.unit ?? '斤',
      sweetness: overrides.sweetness ?? '甜',
      weight: overrides.weight ?? '1kg',
      image: overrides.image ?? 'http://example.com/test.jpg',
      color: overrides.color ?? '#FF6B35',
      categoryId: overrides.categoryId ?? 1,
      stock: overrides.stock ?? 100,
      ...overrides,
    };
    const res = await request(this.httpServer)
      .post('/api/products')
      .set('Authorization', `Bearer ${token}`)
      .send(body);
    if (res.body?.code !== 0) {
      throw new Error(`createProductAsAdmin failed: code=${res.body?.code} message=${res.body?.message}`);
    }
    return res.body.data.id;
  }

  /**
   * 以指定用户身份加入购物车
   */
  async addToCartAsUser(
    token: string,
    productId: number,
    specLabel: string,
    quantity: number,
  ): Promise<void> {
    const res = await request(this.httpServer)
      .post('/api/cart')
      .set('Authorization', `Bearer ${token}`)
      .send({ productId, specLabel, quantity });
    if (res.body?.code !== 0) {
      throw new Error(`addToCartAsUser failed: code=${res.body?.code} message=${res.body?.message}`);
    }
  }
```

- [ ] **Step 2: 不需单独测试，e2e 中使用即可**

- [ ] **Step 3: Commit**

```bash
git add packages/server/test/helpers/test-helper.ts
git commit -m "test(helper): 新增 createProductAsAdmin / addToCartAsUser 助手"
```

---

## Task 13: e2e — auth 扩写（登出黑名单、token 类型、过期）

**Files:**

- Modify: `packages/server/test/auth.e2e-spec.ts`（在 Rate limiting describe **之前**插入新 describe）

- [ ] **Step 1: 在 logout describe 块之后、Rate limiting 之前，插入**

```typescript
describe('Logout 黑名单 + token 类型校验', () => {
  let accessToken: string;
  let refreshToken: string;
  let userTokens: { accessToken: string; refreshToken: string };

  beforeAll(async () => {
    userTokens = await helper.registerAndLogin('13800000010', 'test123456');
    accessToken = userTokens.accessToken;
    refreshToken = userTokens.refreshToken;
  });

  it('should reject access after logout (Redis blacklist)', async () => {
    // 先登出
    await request(helper.httpServer)
      .post('/api/auth/logout')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);

    // 再用同一 token 访问需鉴权接口 → 401
    return request(helper.httpServer)
      .get('/api/user/profile')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(401);
      });
  });

  it('should reject refresh with access token (wrong type)', () => {
    return request(helper.httpServer)
      .post('/api/auth/refresh')
      .send({ refreshToken: accessToken }) // 误用 accessToken
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(401);
      });
  });

  it('should reject invalid/expired refresh token', () => {
    return request(helper.httpServer)
      .post('/api/auth/refresh')
      .send({ refreshToken: 'aaa.bbb.ccc' }) // 非法 JWT
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(401);
      });
  });
});
```

**注意**：此 describe 必须位于 "Rate limiting" describe 之前，避免限流配额被消耗导致 flaky。

- [ ] **Step 2: 跑 e2e（需 docker compose 已起 mysql+redis）**

```bash
docker compose up -d mysql redis
pnpm --filter server test:e2e -- test/auth.e2e-spec.ts
```

Expected: 含新 3 用例全绿

- [ ] **Step 3: Commit**

```bash
git add packages/server/test/auth.e2e-spec.ts
git commit -m "test(e2e/auth): 补登出黑名单/token 类型/非法 refresh 用例"
```

---

## Task 14: e2e — product 扩写（权限、筛选、缓存）

**Files:**

- Modify: `packages/server/test/product.e2e-spec.ts`

- [ ] **Step 1: 先读现有文件，在末尾追加 describe**

```bash
cat packages/server/test/product.e2e-spec.ts
```

- [ ] **Step 2: 在文件末尾 `});` 之前追加**

```typescript
describe('权限控制（非 admin）', () => {
  let userToken: string;

  beforeAll(async () => {
    // 此文件 beforeAll 中 admin 已注册（参考现有写法），此处再注册一个普通 USER
    const u = await helper.registerAndLogin('13800000050', 'test123456');
    userToken = u.accessToken;
  });

  it('should reject USER creating product (403)', () => {
    return request(helper.httpServer)
      .post('/api/products')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ name: 'x', price: 1, categoryId: 1, stock: 1 })
      .expect(200)
      .expect((res) => {
        // ForbiddenException(403) → code 403
        expect(res.body.code).toBe(403);
      });
  });

  it('should reject USER updating product (403)', () => {
    return request(helper.httpServer)
      .put('/api/products/1')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ name: 'y' })
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(403);
      });
  });

  it('should reject USER deleting product (403)', () => {
    return request(helper.httpServer)
      .delete('/api/products/1')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(403);
      });
  });
});

describe('查询与筛选', () => {
  it('should filter by categoryId', () => {
    return request(helper.httpServer)
      .get('/api/products?categoryId=1')
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(0);
        expect(Array.isArray(res.body.data.list)).toBe(true);
        res.body.data.list.forEach((p: any) => {
          expect(p.categoryId).toBe(1);
        });
      });
  });

  it('should filter by keyword', () => {
    return request(helper.httpServer)
      .get('/api/products?keyword=' + encodeURIComponent('商品'))
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(0);
        res.body.data.list.forEach((p: any) => {
          expect(p.name).toContain('商品');
        });
      });
  });

  it('should respect pagination', () => {
    return request(helper.httpServer)
      .get('/api/products?page=1&limit=2')
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(0);
        expect(res.body.data.limit).toBe(2);
        expect(res.body.data.list.length).toBeLessThanOrEqual(2);
      });
  });
});
```

**注**：GET /products 无 @Public，但作为全局默认受 JwtAuthGuard 保护。如需无 token 用例，需先确认此点（在本文件的已有 beforeAll 中通常已有 userToken，可补一个无 token 请求）。

- [ ] **Step 3: 跑 e2e**

```bash
pnpm --filter server test:e2e -- test/product.e2e-spec.ts
```

Expected: 新增 6 用例全绿

- [ ] **Step 4: Commit**

```bash
git add packages/server/test/product.e2e-spec.ts
git commit -m "test(e2e/product): 补权限/筛选/分页用例"
```

---

## Task 15: e2e — cart 扩写（越权、商品不存在）

**Files:**

- Modify: `packages/server/test/cart.e2e-spec.ts`

- [ ] **Step 1: 读现有文件，在末尾追加**

```typescript
describe('越权与边界', () => {
  let userA: { accessToken: string; userId: number };
  let userB: { accessToken: string; userId: number };
  let userBCartId: number;

  beforeAll(async () => {
    userA = await helper.registerAndLogin('13800000060', 'test123456');
    userB = await helper.registerAndLogin('13800000061', 'test123456');
    // B 加一个商品到购物车
    const productRes = await request(helper.httpServer)
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: 'Cart 越权测试商品',
        price: 1,
        categoryId: 1,
        stock: 10,
        unit: '斤',
        origin: 'x',
        sweetness: '甜',
        weight: '1kg',
        image: 'i',
        color: '#fff',
      });
    // 注：adminToken 需在此文件 beforeAll 已定义；若未定义需先在文件顶部 beforeAll 注册 admin
    const productId = productRes.body.data.id;
    const addRes = await request(helper.httpServer)
      .post('/api/cart')
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .send({ productId, specLabel: '1kg', quantity: 1 });
    userBCartId = addRes.body.data.id ?? addRes.body.data[0]?.id; // 取列表中 B 的 cart id
    // 若返回是 list，需从 list 找：
    const listRes = await request(helper.httpServer)
      .get('/api/cart')
      .set('Authorization', `Bearer ${userB.accessToken}`);
    userBCartId = listRes.body.data[0].id;
  });

  it('should reject adding non-existent product (404)', () => {
    return request(helper.httpServer)
      .post('/api/cart')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .send({ productId: 999999, specLabel: '1kg', quantity: 1 })
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(404);
      });
  });

  it('should reject A updating B cart (404)', () => {
    return request(helper.httpServer)
      .put(`/api/cart/${userBCartId}`)
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .send({ quantity: 99 })
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(404);
      });
  });

  it('should reject A deleting B cart (404)', () => {
    return request(helper.httpServer)
      .delete(`/api/cart/${userBCartId}`)
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(404);
      });
  });

  it('should reject no-token GET /cart (401)', () => {
    return request(helper.httpServer)
      .get('/api/cart')
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(401);
      });
  });
});
```

**注**：若 cart.e2e 现有 beforeAll 没有注册 admin，需要在追加前先在文件 beforeAll 中补 admin 注册（参考 order.e2e 的写法）。

- [ ] **Step 2: 跑 e2e**

```bash
pnpm --filter server test:e2e -- test/cart.e2e-spec.ts
```

Expected: 新增 4 用例全绿

- [ ] **Step 3: Commit**

```bash
git add packages/server/test/cart.e2e-spec.ts
git commit -m "test(e2e/cart): 补越权改/删与商品不存在用例"
```

---

## Task 16: e2e — order 扩写（取消/查询他人订单）

**Files:**

- Modify: `packages/server/test/order.e2e-spec.ts`

- [ ] **Step 1: 在末尾追加**

```typescript
describe('越权与边界', () => {
  let userA: { accessToken: string; userId: number };
  let userB: { accessToken: string; userId: number };
  let userBOrderId: number;

  beforeAll(async () => {
    userA = await helper.registerAndLogin('13800000070', 'test123456');
    userB = await helper.registerAndLogin('13800000071', 'test123456');
    // 为 B 创建一笔订单
    const productId = await helper.createProductAsAdmin(adminToken, { name: 'B 的订单商品' });
    await helper.addToCartAsUser(userB.accessToken, productId, '1kg', 1);
    const res = await request(helper.httpServer)
      .post('/api/orders')
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .send({ address: '北京市', phone: '13800000071' });
    userBOrderId = res.body.data.id;
  });

  it('should reject A cancelling B order (404)', () => {
    return request(helper.httpServer)
      .put(`/api/orders/${userBOrderId}/cancel`)
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(404);
      });
  });

  it('should reject A viewing B order detail (404)', () => {
    return request(helper.httpServer)
      .get(`/api/orders/${userBOrderId}`)
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(404);
      });
  });

  it('should reject no-token POST /orders (401)', () => {
    return request(helper.httpServer)
      .post('/api/orders')
      .send({ address: 'x', phone: '13800000099' })
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(401);
      });
  });

  it('should reject cancelling non-existent order (404)', () => {
    return request(helper.httpServer)
      .put('/api/orders/99999/cancel')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(404);
      });
  });
});
```

- [ ] **Step 2: 跑 e2e**

```bash
pnpm --filter server test:e2e -- test/order.e2e-spec.ts
```

Expected: 新增 4 用例全绿

- [ ] **Step 3: Commit**

```bash
git add packages/server/test/order.e2e-spec.ts
git commit -m "test(e2e/order): 补取消/查询他人订单与无 token 用例"
```

---

## Task 17: e2e — user 扩写（无 token、更新 profile、串号校验）

**Files:**

- Modify: `packages/server/test/user.e2e-spec.ts`

- [ ] **Step 1: 在末尾追加**

```typescript
describe('权限与更新', () => {
  let userA: { accessToken: string; userId: number };
  let userB: { accessToken: string; userId: number };

  beforeAll(async () => {
    userA = await helper.registerAndLogin('13800000080', 'test123456', 'A');
    userB = await helper.registerAndLogin('13800000081', 'test123456', 'B');
  });

  it('should reject no-token GET /user/profile (401)', () => {
    return request(helper.httpServer)
      .get('/api/user/profile')
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(401);
      });
  });

  it('should update own nickname', () => {
    return request(helper.httpServer)
      .put('/api/user/profile')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .send({ nickname: 'New Nickname' })
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(0);
        expect(res.body.data.nickname).toBe('New Nickname');
      });
  });

  it('should not leak B profile to A token (based on JWT userId)', () => {
    // A 的 token 只能查 A 自己的 profile
    return request(helper.httpServer)
      .get('/api/user/profile')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.code).toBe(0);
        expect(res.body.data.id).toBe(userA.userId);
        expect(res.body.data.id).not.toBe(userB.userId);
      });
  });
});
```

- [ ] **Step 2: 跑 e2e**

```bash
pnpm --filter server test:e2e -- test/user.e2e-spec.ts
```

Expected: 新增 3 用例全绿

- [ ] **Step 3: Commit**

```bash
git add packages/server/test/user.e2e-spec.ts
git commit -m "test(e2e/user): 补无 token/更新 profile/串号校验用例"
```

---

## Task 18: 全套 e2e 验证

**Files:** 无新增

- [ ] **Step 1: 起 docker 依赖**

```bash
docker compose up -d mysql redis
```

- [ ] **Step 2: 确认 shared dist 最新**

```bash
pnpm --filter shared build
```

- [ ] **Step 3: 跑全套 e2e（串行）**

```bash
pnpm --filter server test:e2e
```

Expected: 所有 e2e（6 个文件）全部 PASS，无 flaky

- [ ] **Step 4: 把输出贴给用户**

---

## Task 19: 全套 unit + e2e 最终验证

- [ ] **Step 1: 单测**

```bash
pnpm --filter server test:unit 2>&1 | tail -30
```

- [ ] **Step 2: e2e**

```bash
pnpm --filter server test:e2e 2>&1 | tail -30
```

- [ ] **Step 3: 把两份输出交给用户 review**

- [ ] **Step 4: 若一切通过，最终 commit（如有遗漏的 mock 修正）**

```bash
git add -A
git commit -m "test(server): 全套测试补齐收尾"
```

---

## Self-Review

**1. Spec coverage:**

- service 单测 5 个 → Task 1-5 ✓
- common 单测 5 个 → Task 6-10 ✓
- TestHelper 扩展 → Task 12 ✓
- e2e 5 个文件扩写 → Task 13-17 ✓
- 自测 unit → Task 11 ✓
- 自测 e2e → Task 18 ✓
- 最终验证 → Task 19 ✓

**2. Placeholder scan:**

- Task 4 Step 1 有「重要修正」提示（orderRepo.save 需在 beforeEach 加）→ 已显式说明，非占位
- Task 15/16 中 adminToken 引用：已在步骤内注明「若未定义需先补」，属可执行提示，非占位
- 无 "TBD/TODO"

**3. Type consistency:**

- `createProductAsAdmin(token, overrides)` 在 Task 12 定义，Task 16 使用 ✓
- `addToCartAsUser(token, productId, specLabel, quantity)` 同上 ✓
- mock Redis 方法名（get/set/keys/del）在 product/cart/auth spec 一致 ✓
- queryRunner.manager.createQueryBuilder 链式签名一致 ✓

**4. 已知风险（实施时注意）：**

- Task 5 `jest.mock('uuid')` 可能影响其他 module 对 uuid 的引用 —— 因 spec 文件独立 jest 作用域，OK
- Task 7 `super.canActivate` mock 方式：用 spyOn 原型链，若 NestJS 版本升级可能失效 —— 本项目 NestJS 10 固定，OK
- e2e 手机号必须跨文件唯一，本计划已分配号段（80/70/60/50/10），避免冲突
