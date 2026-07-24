---
spec_ref: ../specs/2026-07-24-fruit-shop-code-quality-design.md
spec_topic: fruit-shop-code-quality
task_count: 12
estimated_phases: [implementation, verification]
dod: 'D1-D9 per docs/agent-harness/contracts/fruit-shop-code-quality.contract.md'
---

# 鲜果集代码质量优化 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 demo/fruit-shop 引入 ESLint + Prettier + 单元测试框架，拆分 Order Service，补齐数据库索引并加固安全配置

**Architecture:** 分三个 Phase 执行——Phase 1 纯工具链配置（零回归风险），Phase 2 核心代码治理（facade 拆分 + 索引 + 安全加固），Phase 3 示例测试。每个 Task 可独立验证。

**Tech Stack:** ESLint 9 (flat config), Prettier 3, Jest 30 (@golevelup/ts-jest), Vitest, @testing-library/react, TypeORM @Index()

**Commit strategy:** 每个 Task 完成后自动 commit

---

## Phase 1: 工具链基础设施

### Task 1: 创建 ESLint + Prettier 配置文件

Blocking: none
Slice type: tracer-bullet
Seam: `pnpm lint` exit code 0（首次允许 warning，不允许 crash）

**Files:**

- Create: `eslint.config.js`
- Create: `.prettierrc`
- Create: `.prettierignore`
- Create: `.editorconfig`
- Modify: `package.json` (根目录)

- [ ] **Step 1: 创建 `.prettierrc`**

```json
{
  "semi": true,
  "singleQuote": true,
  "printWidth": 100,
  "trailingComma": "all",
  "tabWidth": 2,
  "endOfLine": "lf"
}
```

- [ ] **Step 2: 创建 `.prettierignore`**

```
dist/
node_modules/
coverage/
pnpm-lock.yaml
packages/server/uploads/
```

- [ ] **Step 3: 创建 `.editorconfig`**

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
indent_style = space
indent_size = 2
insert_final_newline = true
trim_trailing_whitespace = true

[*.md]
trim_trailing_whitespace = false

[*.{yml,yaml}]
indent_size = 2
```

- [ ] **Step 4: 创建 `eslint.config.js`（flat config）**

```javascript
const js = require('@eslint/js');
const tseslint = require('typescript-eslint');
const react = require('eslint-plugin-react');
const prettier = require('eslint-config-prettier');

module.exports = tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ['packages/web/**/*.{ts,tsx}'],
    ...react.configs.flat['recommended-typescript'],
    settings: { react: { version: '18' } },
    rules: {
      'react/prop-types': 'off',
    },
  },
  {
    files: ['packages/server/src/**/*.ts'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'warn',
      '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
    },
  },
  prettier,
  {
    ignores: ['dist/', 'node_modules/', '*.config.js', 'coverage/', 'packages/server/uploads/'],
  },
);
```

- [ ] **Step 5: 修改根目录 `package.json`，添加 devDependencies 和脚本**

在 `devDependencies` 中添加：

```json
{
  "eslint": "^9.0.0",
  "@eslint/js": "^9.0.0",
  "typescript-eslint": "^8.0.0",
  "eslint-plugin-react": "^4.0.0",
  "eslint-config-prettier": "^10.0.0",
  "prettier": "^3.0.0"
}
```

在 `scripts` 中添加：

```json
{
  "lint": "eslint .",
  "lint:fix": "eslint . --fix",
  "format": "prettier --write .",
  "format:check": "prettier --check .",
  "test:unit": "pnpm -r run test:unit"
}
```

- [ ] **Step 6: 安装依赖并验证**

Run (项目根目录): `pnpm install`
Expected: 安装成功，无 peer dependency 冲突

Run: `pnpm lint --no-error-on-unmatched-pattern`
Expected: ESLint 运行成功（可能有 lint error，但不应 crash）

- [ ] **Step 7: Commit**

```bash
git add eslint.config.js .prettierrc .prettierignore .editorconfig package.json pnpm-lock.yaml
git commit -m "chore: add ESLint flat config, Prettier, and EditorConfig"
```

---

### Task 2: 配置 Server 端单元测试框架 (Jest)

Blocking: none
Slice type: tracer-bullet
Seam: `pnpm --filter server test:unit` 能执行（即使 0 tests 通过）

**Files:**

- Create: `packages/server/jest.unit.config.ts`
- Modify: `packages/server/package.json`

- [ ] **Step 1: 创建 `jest.unit.config.ts`**

```typescript
import type { Config } from 'jest';

const config: Config = {
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/*.spec.ts'],
  moduleNameMapper: {
    '^shared$': '<rootDir>/../shared/src/index.ts',
  },
  transform: {
    '^.+\\.tsx?$': [
      'ts-jest',
      {
        tsconfig: '<rootDir>/tsconfig.json',
      },
    ],
  },
};
export default config;
```

> 注意：server 已有 `ts-jest` 在 devDependencies 中（见 package.json），无需额外安装。

- [ ] **Step 2: 确认 `packages/server/package.json` 的 `test:unit` 脚本**

当前已有 `"test:unit": "NODE_ENV=test jest --config jest.config.ts"`。需要改为指向新配置文件：

修改为：

```json
"test:unit": "NODE_ENV=test jest --config jest.unit.config.ts"
```

- [ ] **Step 3: 验证 Jest unit config 可加载**

Run (packages/server 目录): `pnpm test:unit --passWithNoTests`
Expected: exit code 0，输出 "No tests found, exiting with code 0"

- [ ] **Step 4: Commit**

```bash
git add packages/server/jest.unit.config.ts packages/server/package.json
git commit -m "chore(server): add Jest unit test configuration"
```

---

### Task 3: 配置 Web 端单元测试框架 (Vitest)

Blocking: none
Slice type: tracer-bullet
Seam: `pnpm --filter web test:unit` 能执行

**Files:**

- Modify: `packages/web/vite.config.ts`
- Modify: `packages/web/package.json`

- [ ] **Step 1: 修改 `packages/web/vite.config.ts`，添加 Vitest 插件**

在文件顶部添加 vitest 类型引用：

```typescript
/// <reference types="vitest" />
```

在 `plugins` 数组中添加 vitest 配置块：

```typescript
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      shared: path.resolve(__dirname, '../shared/src/index.ts'),
    },
  },
  server: {
    port: 5177,
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },
  // ↓ 新增
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/test-setup.ts'],
  },
});
```

- [ ] **Step 2: 创建测试 setup 文件 `packages/web/src/test-setup.ts`**

```typescript
import '@testing-library/jest-dom/vitest';
```

- [ ] **Step 3: 修改 `packages/web/package.json`，添加依赖和脚本**

在 `devDependencies` 中添加：

```json
{
  "vitest": "^3.0.0",
  "@testing-library/react": "^16.0.0",
  "@testing-library/jest-dom": "^6.0.0",
  "@testing-library/user-event": "^14.0.0",
  "jsdom": "^25.0.0"
}
```

在 `scripts` 中添加：

```json
{
  "test:unit": "vitest run",
  "test:unit:watch": "vitest"
}
```

- [ ] **Step 4: 安装依赖并验证**

Run (项目根目录): `pnpm install`
Expected: 安装成功

Run (packages/web 目录): `pnpm test:unit --run`
Expected: exit code 0（无测试文件时 vitest 默认退出码为 0）

- [ ] **Step 5: Commit**

```bash
git add packages/web/vite.config.ts packages/web/src/test-setup.ts packages/web/package.json pnpm-lock.yaml
git commit -m "chore(web): add Vitest and Testing Library configuration"
```

---

## Phase 2: 代码治理

### Task 4: 拆分 Order Service — 提取 OrderCheckoutService

Blocking: Task 1
Slice type: refactor
Seam: `order.service.ts` 行数从 567 减少到 ~200；e2e 测试全过

**Files:**

- Create: `packages/server/src/modules/order/order-checkout.service.ts`
- Modify: `packages/server/src/modules/order/order.service.ts`

- [ ] **Step 1: 创建 `order-checkout.service.ts`，从 order.service.ts 提取下单逻辑**

将 `create()` 方法（原第 52-255 行）及其所需的所有 constructor 依赖完整提取到新文件：

```typescript
import { Injectable, BadRequestException } from '@nestjs/common';
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
    // ← 完整复制原 order.service.ts 的 create() 方法体（第 52-255 行）
    // 包括：购物车校验、地址解析、事务内行锁扣库存、优惠券核销、创建订单/订单项、清空购物车
    // 注意：方法签名和返回值不变
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
        await queryRunner.manager.query('UPDATE products SET stock = stock - ? WHERE id = ?', [
          item.quantity,
          item.productId,
        ]);
      }

      let discountAmount = 0;
      let userCouponDbId: number | null = null;
      let couponTemplateId: number | null = null;
      if (dto.couponId) {
        const ucRows: {
          id: number;
          user_id: number;
          coupon_id: number;
          used_at: Date | null;
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
        discountAmount = this.couponService.calculateDiscount(
          template,
          orderItems.map((i) => ({
            productId: i.productId!,
            quantity: i.quantity!,
            price: Number(i.price),
            categoryId: item_product_category.get(i.productId!)!,
          })),
        );
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
        {
          orderId: savedOrder.id,
          orderNo,
          userId,
          totalAmount: finalTotalAmount,
          itemCount: orderItems.length,
          couponId: couponTemplateId,
          discountAmount,
        },
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
```

> **关键差异**: 原 `create()` 最后返回 `this.findOne(userId, savedOrder.id)`，提取后改为返回 `savedOrder`（纯 entity），由 facade 层的 `OrderService.create()` 调用 `this.checkoutService.create()` 后再调用 `this.findOne()` 包装。

- [ ] **Step 2: 重构 `order.service.ts` 为 Facade**

替换整个文件内容为：

```typescript
import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
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
    const qb = this.orderRepo.createQueryBuilder('o').where('o.user_id = :userId', { userId });
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

  /** 取消订单 → 委托给 LifecycleService */
  async cancel(userId: number, id: number) {
    return this.lifecycleService.cancel(userId, id, () => this.findOne(userId, id));
  }

  /** 支付 → 委托给 LifecycleService */
  async pay(userId: number, id: number) {
    return this.lifecycleService.pay(userId, id, () => this.findOne(userId, id));
  }

  /** 发货 → 委托给 LifecycleService (Admin) */
  async ship(id: number, dto: ShipDto) {
    return this.lifecycleService.ship(id, dto, () => this.findOneInternal(id));
  }

  /** 确认收货 → 委托给 LifecycleService */
  async confirm(userId: number, id: number) {
    return this.lifecycleService.confirm(userId, id, () => this.findOne(userId, id));
  }

  /** 申请退款 → 委托给 LifecycleService */
  async requestRefund(userId: number, id: number, dto: RefundRequestDto) {
    return this.lifecycleService.requestRefund(userId, id, dto, () => this.findOne(userId, id));
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
```

- [ ] **Step 3: 验证行数**

Run: `wc -l packages/server/src/modules/order/order.service.ts`
Expected: ≤ 150 行

- [ ] **Step 4: Commit**

```bash
git add packages/server/src/modules/order/order-checkout.service.ts packages/server/src/modules/order/order.service.ts
git commit -m "refactor(order): extract OrderCheckoutService from OrderService"
```

---

### Task 5: 拆分 Order Service — 提取 OrderLifecycleService + 注册到 Module

Blocking: Task 4
Slice type: refactor
Seam: e2e 测试全部通过

**Files:**

- Create: `packages/server/src/modules/order/order-lifecycle.service.ts`
- Modify: `packages/server/src/modules/order/order.module.ts`

- [ ] **Step 1: 创建 `order-lifecycle.service.ts`，提取状态流转方法**

从原 `order.service.ts` 提取 `cancel/pay/ship/confirm/requestRefund` 五个方法（原第 297-538 行）。每个方法接收一个 `findOne` 回调以避免循环依赖：

```typescript
import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { OrderEntity, OrderItemEntity, RefundEntity } from '../../entities';
import { ShipDto } from './dto/ship.dto';
import { RefundRequestDto } from './dto/refund-request.dto';
import { OrderStatus, ErrorCode, ErrorMessage, RefundStatus } from 'shared';
import { PinoLogger } from 'nestjs-pino';

@Injectable()
export class OrderLifecycleService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly logger: PinoLogger,
  ) {
    this.logger.setContext(OrderLifecycleService.name);
  }

  async cancel(userId: number, id: number, findOne: (uid: number, id: number) => Promise<any>) {
    // ← 完整复制原 cancel() 方法体（第 297-374 行）
    // 唯一改动：最后的 return this.findOne(userId, id) 改为 return findOne(userId, id)
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const rows: { id: number; status: number }[] = await queryRunner.manager.query(
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
          code: ErrorCode.ORDER_CANCEL_NOT_ALLOWED,
          message: ErrorMessage[ErrorCode.ORDER_CANCEL_NOT_ALLOWED],
        });
      }
      const items = await queryRunner.manager.find(OrderItemEntity, { where: { orderId: id } });
      const productIds = items.map((i) => i.productId);
      if (productIds.length > 0) {
        await queryRunner.manager.query('SELECT id FROM products WHERE id IN (?) FOR UPDATE', [
          productIds,
        ]);
        for (const item of items) {
          await queryRunner.manager.query('UPDATE products SET stock = stock + ? WHERE id = ?', [
            item.quantity,
            item.productId,
          ]);
        }
      }
      await queryRunner.manager.query('UPDATE orders SET status = ? WHERE id = ?', [
        OrderStatus.CANCELLED,
        id,
      ]);
      const couponRows: { coupon_id: number | null }[] = await queryRunner.manager.query(
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
    return findOne(userId, id);
  }

  async pay(userId: number, id: number, findOne: (uid: number, id: number) => Promise<any>) {
    // ← 复制原 pay() 方法体（第 376-410 行），末尾 return findOne(userId, id)
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      const rows: { id: number; status: number }[] = await queryRunner.manager.query(
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
    return findOne(userId, id);
  }

  async ship(id: number, dto: ShipDto, findOne: (id: number) => Promise<any>) {
    // ← 复制原 ship() 方法体（第 412-454 行），末尾 return findOneInternal(id)
    const { ShippingEntity } = require('../../entities');
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      const rows: { id: number; status: number }[] = await queryRunner.manager.query(
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
    return findOne(id);
  }

  async confirm(userId: number, id: number, findOne: (uid: number, id: number) => Promise<any>) {
    // ← 复制原 confirm() 方法体（第 456-490 行），末尾 return findOne(userId, id)
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      const rows: { id: number; status: number }[] = await queryRunner.manager.query(
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
      await queryRunner.manager.query('UPDATE orders SET status = ? WHERE id = ?', [
        OrderStatus.COMPLETED,
        id,
      ]);
      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
    return findOne(userId, id);
  }

  async requestRefund(
    userId: number,
    id: number,
    dto: RefundRequestDto,
    findOne: (uid: number, id: number) => Promise<any>,
  ) {
    // ← 复制原 requestRefund() 方法体（第 492-538 行），末尾 return findOne(userId, id)
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();
    try {
      const rows: { id: number; status: number }[] = await queryRunner.manager.query(
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
      if (currentStatus !== OrderStatus.PAID && currentStatus !== OrderStatus.SHIPPED) {
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
      await queryRunner.manager.query('UPDATE orders SET status = ? WHERE id = ?', [
        OrderStatus.REFUNDING,
        id,
      ]);
      await queryRunner.commitTransaction();
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
    return findOne(userId, id);
  }
}
```

- [ ] **Step 2: 修改 `order.module.ts`，注册两个新 service**

在 `providers` 数组中添加 `OrderCheckoutService` 和 `OrderLifecycleService`：

```typescript
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
import { OrderController } from './order.controller';
import { OrderCheckoutService } from './order-checkout.service';
import { OrderLifecycleService } from './order-lifecycle.service';

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
```

- [ ] **Step 3: 验证 TypeScript 编译通过**

Run (packages/server 目录): `npx tsc --noEmit`
Expected: 无编译错误

- [ ] **Step 4: Commit**

```bash
git add packages/server/src/modules/order/order-lifecycle.service.ts packages/server/src/modules/order/order.module.ts
git commit -m "refactor(order): extract OrderLifecycleService and register in module"
```

---

### Task 6: 数据库索引 — 6 张表新增 @Index()

Blocking: none
Slice type: refactor
Seam: grep 确认 @Index 装饰器存在

**Files:**

- Modify: `packages/server/src/entities/cart.entity.ts`
- Modify: `packages/server/src/entities/order.entity.ts`
- Modify: `packages/server/src/entities/order-item.entity.ts`
- Modify: `packages/server/src/entities/review.entity.ts`
- Modify: `packages/server/src/entities/favorite.entity.ts`
- Modify: `packages/server/src/entities/coupon-template.entity.ts`

- [ ] **Step 1: 修改 `cart.entity.ts`，添加 `@Index(['userId'])`**

在 `@Unique(['userId', 'productId', 'specLabel'])` 之后添加：

```typescript
import { Index } from 'typeorm';

// 在类声明上方添加：
@Index(['userId'])
@Entity('carts')
@Unique(['userId', 'productId', 'specLabel'])
export class CartEntity {
```

- [ ] **Step 2: 修改 `order.entity.ts`，添加两个索引**

```typescript
@Index(['userId'])
@Index(['status'])
@Entity('orders')
export class OrderEntity {
```

- [ ] **Step 3: 修改 `order-item.entity.ts`，添加 orderId 索引**

```typescript
@Index(['orderId'])
@Entity('order_items')
export class OrderItemEntity {
```

- [ ] **Step 4: 修改 `review.entity.ts`，添加两个索引**

```typescript
@Index(['productId'])
@Index(['userId'])
@Entity('reviews')
@Unique(['orderId', 'productId'])
export class ReviewEntity {
```

- [ ] **Step 5: 修改 `favorite.entity.ts`，添加两个索引**

```typescript
@Index(['userId'])
@Index(['productId'])
@Entity('favorites')
@Unique(['userId', 'productId'])
export class FavoriteEntity {
```

- [ ] **Step 6: 修改 `coupon-template.entity.ts`，添加复合索引**

先确认文件存在并读取其内容（字段名可能不同）：

```bash
# 先检查文件是否存在
ls packages/server/src/entities/coupon-template.entity.ts
```

预期添加（根据 spec 设计中的复合索引）：

```typescript
@Index(['status', 'startAt', 'endTime'])
@Entity('coupons_templates')  // 或实际表名
export class CouponTemplateEntity {
```

> 若该文件不存在或字段名不匹配，grep 确认实际实体名后调整。

- [ ] **Step 7: 验证编译 + grep 确认**

Run: `cd packages/server && npx tsc --noEmit`
Expected: 编译通过

Run: `grep -r "@Index" packages/server/src/entities/ | wc -l`
Expected: 至少 8 个匹配（≥ 6 表 × 平均 1-2 个索引）

- [ ] **Step 8: Commit**

```bash
git add packages/server/src/entities/
git commit -m "perf(entity): add database indexes for high-query tables"
```

---

### Task 7: 安全加固 — synchronize 环境化 + Token 解析 + CORS + JWT 校验

Blocking: none
Slice type: tracer-bullet
Seam: 启动时可观察到 warning/error 日志

**Files:**

- Modify: `packages/server/src/config/database.config.ts`
- Modify: `packages/server/src/modules/auth/auth.controller.ts`
- Modify: `packages/server/src/main.ts`
- Modify: `packages/server/src/modules/auth/auth.service.ts`

- [ ] **Step 1: 修改 `database.config.ts`，synchronize 读环境变量**

```typescript
import { ConfigService } from '@nestjs/config';
import { TypeOrmModuleOptions } from '@nestjs/typeorm';

export const databaseConfig = (configService: ConfigService): TypeOrmModuleOptions => {
  const dbSync = configService.get<string>('DB_SYNC', 'true');

  if (process.env.NODE_ENV === 'production' && dbSync !== 'false') {
    console.warn(
      '[WARNING] DB_SYNC is not explicitly disabled in production. ' +
        'Set DB_SYNC=false to prevent automatic schema changes.',
    );
  }

  return {
    type: 'mysql',
    host: configService.get<string>('DB_HOST', 'localhost'),
    port: configService.get<number>('DB_PORT', 3306),
    username: configService.get<string>('DB_USERNAME', 'root'),
    password: configService.get<string>('DB_PASSWORD', 'root123'),
    database: configService.get<string>('DB_DATABASE', 'fruit_shop'),
    autoLoadEntities: true,
    synchronize: dbSync === 'true',
    logging: configService.get<string>('DB_LOGGING', 'false') === 'true',
    timezone: '+08:00',
    charset: 'utf8mb4',
  };
};
```

- [ ] **Step 2: 修改 `auth.controller.ts`，Token 解析正则化**

将第 71-72 行：

```typescript
const authHeader = req.headers.authorization || '';
const token = authHeader.replace('Bearer ', '');
```

替换为：

```typescript
const authHeader = req.headers.authorization || '';
const match = authHeader.match(/^Bearer\s+(.+)$/i);
const token = match?.[1] ?? '';
```

- [ ] **Step 3: 修改 `main.ts`，CORS 可配置**

将第 24-27 行：

```typescript
app.enableCors({
  origin: true,
  credentials: true,
});
```

替换为：

```typescript
const corsOrigins = process.env.CORS_ORIGINS;
app.enableCors({
  origin: corsOrigins ? corsOrigins.split(',') : true,
  credentials: true,
});
```

- [ ] **Step 4: 修改 `auth.service.ts`，JWT Secret 启动校验**

在 `constructor` 之后添加 `OnModuleInit` 生命周期钩子：

1. 在 import 区域添加 `OnInit`：

```typescript
import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  Inject,
  OnInit,
} from '@nestjs/common';
```

2. 让 class 实现 `OnInit`：

```typescript
export class AuthService implements OnInit {
```

3. 添加 `onModuleInit` 方法（在 `register` 方法之前）：

```typescript
onModuleInit() {
  const secret = this.configService.get<string>(
    'JWT_SECRET',
    'your-jwt-secret-change-in-prod',
  );

  const DEFAULT_SECRET = 'your-jwt-secret-change-in-prod';
  if (secret === DEFAULT_SECRET) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error(
        '[FATAL] JWT_SECRET is using the default value in production. ' +
        'Set a strong random string via JWT_SECRET environment variable.',
      );
    }
    console.warn(
      '[WARNING] JWT_SECRET is using the default value. ' +
      'This is unsafe for production. Set JWT_SECRET environment variable.',
    );
  }
}
```

- [ ] **Step 5: 验证编译**

Run (packages/server): `npx tsc --noEmit`
Expected: 无错误

- [ ] **Step 6: Commit**

```bash
git add packages/server/src/config/database.config.ts packages/server/src/modules/auth/auth.controller.ts packages/server/src/main.ts packages/server/src/modules/auth/auth.service.ts
git commit -m "security: env-based DB_SYNC, regex token parse, configurable CORS, JWT secret validation"
```

---

## Phase 3: 示例测试

### Task 8: Auth Service 单元测试

Blocking: Task 2
Slice type: tracer-bullet
Seam: ≥ 4 个测试用例通过

**Files:**

- Create: `packages/server/src/modules/auth/auth.service.spec.ts`

- [ ] **Step 1: 创建 `auth.service.spec.ts`**

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthService } from './auth.service';
import { UserEntity } from '../../entities/user.entity';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';

describe('AuthService', () => {
  let service: AuthService;
  let userRepo: MockType<Partial<Repository<UserEntity>>>;
  let jwtService: { signAsync: jest.Mock };

  type MockType<T> = {
    [P in keyof T]: jest.Mock<T[P]>;
  };

  beforeEach(async () => {
    userRepo = {
      findOne: jest.fn(),
      create: jest.fn(),
      save: jest.fn(),
    };
    jwtService = {
      signAsync: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: getRepositoryToken(UserEntity), useValue: userRepo },
        { provide: JwtService, useValue: jwtService },
        {
          provide: ConfigService,
          useValue: { get: jest.fn((key: string, fallback: unknown) => fallback) },
        },
        { provide: 'REDIS_CLIENT', useValue: {} },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  describe('register', () => {
    it('should register a new user successfully', async () => {
      userRepo.findOne!.mockResolvedValue(null);
      userRepo.create!.mockReturnValue({ phone: '13800138000' });
      userRepo.save!.mockResolvedValue({ id: 1, phone: '13800138000' });
      jwtService.signAsync.mockResolvedValue('access-token');

      const result = await service.register({ phone: '13800138000', password: 'password123' });

      expect(userRepo.findOne).toHaveBeenCalledWith({ where: { phone: '13800138000' } });
      expect(userRepo.save).toHaveBeenCalled();
      expect(result).toBeDefined();
    });

    it('should throw ConflictException when phone already exists', async () => {
      userRepo.findOne!.mockResolvedValue({ id: 1, phone: '13800138000' });

      await expect(
        service.register({ phone: '13800138000', password: 'password123' }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('login', () => {
    it('should login with correct credentials', async () => {
      const hashedPassword = await bcrypt.hash('password123', 10);
      userRepo.findOne!.mockResolvedValue({
        id: 1,
        phone: '13800138000',
        password: hashedPassword,
        role: 0,
      } as UserEntity);
      jwtService.signAsync
        .mockResolvedValueOnce('access-token')
        .mockResolvedValueOnce('refresh-token');

      const result = await service.login({ phone: '13800138000', password: 'password123' });

      expect(result).toBeDefined();
      expect(jwtService.signAsync).toHaveBeenCalledTimes(2);
    });

    it('should throw UnauthorizedException with wrong password', async () => {
      const hashedPassword = await bcrypt.hash('correct-password', 10);
      userRepo.findOne!.mockResolvedValue({
        id: 1,
        phone: '13800138000',
        password: hashedPassword,
      } as UserEntity);

      await expect(
        service.login({ phone: '13800138000', password: 'wrong-password' }),
      ).rejects.toThrow(UnauthorizedException);
    });
  });
});
```

- [ ] **Step 2: 运行测试**

Run (packages/server): `pnpm test:unit -- src/modules/auth/auth.service.spec.ts`
Expected: 4 tests passed

- [ ] **Step 3: Commit**

```bash
git add packages/server/src/modules/auth/auth.service.spec.ts
git commit -m "test(auth): add unit tests for register and login"
```

---

### Task 9: Cart Service 单元测试

Blocking: Task 2
Slice type: tracer-bullet
Seam: ≥ 2 个测试用例通过

**Files:**

- Create: `packages/server/src/modules/cart/cart.service.spec.ts`

- [ ] **Step 1: 创建 `cart.service.spec.ts`**

先确认 CartService 的公共 API（读取 `cart.service.ts`）：

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CartService } from './cart.service';
import { CartEntity } from '../../entities';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ErrorCode, ErrorMessage } from 'shared';

describe('CartService', () => {
  let service: CartService;
  let cartRepo: {
    find: jest.Mock;
    findOne: jest.Mock;
    save: jest.Mock;
    remove: jest.Mock;
    delete: jest.Mock;
  };

  beforeEach(async () => {
    cartRepo = {
      find: jest.fn(),
      findOne: jest.fn(),
      save: jest.fn(),
      remove: jest.fn(),
      delete: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [CartService, { provide: getRepositoryToken(CartEntity), useValue: cartRepo }],
    }).compile();

    service = module.get<CartService>(CartService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('addToCart / addItem', () => {
    it('should add item to cart when product exists', async () => {
      // Mock: 购物车中无该商品（可新增）
      cartRepo.findOne!.mockResolvedValue(null);
      cartRepo.save!.mockResolvedValue({ id: 1, userId: 1, productId: 100, quantity: 1 });

      // 根据实际的 addItem/addToCart 方法签名调用
      // 此处需根据实际 CartService API 调整
      const result = await service.addItem(1, { productId: 100, quantity: 1, specLabel: '常规' });

      expect(cartRepo.save).toHaveBeenCalled();
      expect(result).toBeDefined();
    });

    it('should throw when product does not exist (if service validates)', async () => {
      // 如果 CartService 会校验 product 存在性，这里模拟 NotFound 场景
      // 具体取决于 CartService 实现
      cartRepo.findOne!.mockResolvedValue(null);

      // 根据 CartService 实际行为调整断言
      expect(true).toBe(true); // placeholder — adjust after reading actual service
    });
  });

  describe('clearCart', () => {
    it('should clear all cart items for a user', async () => {
      cartRepo.delete!.mockResolvedValue({ affected: 3 });

      await service.clearCart(1);

      expect(cartRepo.delete).toHaveBeenCalledWith({ userId: 1 });
    });
  });
});
```

> **注意**: 以上 mock 断言基于 CartService 的常见模式。执行前必须读取实际 `cart.service.ts` 确认方法签名和内部逻辑，调整 mock 和断言使其匹配真实实现。

- [ ] **Step 2: 读取实际 CartService 并调整测试**

Run: `cat packages/server/src/modules/cart/cart.service.ts`
→ 根据实际 API 更新上述测试代码中的方法调用和断言

- [ ] **Step 3: 运行测试**

Run: `pnpm test:unit -- src/modules/cart/cart.service.spec.ts`
Expected: ≥ 2 tests passed

- [ ] **Step 4: Commit**

```bash
git add packages/server/src/modules/cart/cart.service.spec.ts
git commit -m "test(cart): add unit tests for cart operations"
```

---

### Task 10: OrderCheckoutService 单元测试

Blocking: Task 4, Task 8
Slice type: tracer-bullet
Seam: ≥ 2 个测试用例通过

**Files:**

- Create: `packages/server/src/modules/order/order-checkout.service.spec.ts`

- [ ] **Step 1: 创建 `order-checkout.service.spec.ts`**

核心覆盖：空购物车拒绝、库存不足回滚。

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { OrderCheckoutService } from './order-checkout.service';
import { CartEntity, ProductEntity, AddressEntity } from '../../entities';
import { BadRequestException } from '@nestjs/common';
import { ErrorCode, ErrorMessage } from 'shared';

describe('OrderCheckoutService', () => {
  let service: OrderCheckoutService;
  let cartRepo: Partial<Repository<CartEntity>>;
  let addressRepo: Partial<Repository<AddressEntity>>;
  let dataSource: {
    createQueryRunner: jest.Mock;
  };

  beforeEach(async () => {
    cartRepo = { find: jest.fn() };
    addressRepo = { findOne: jest.fn() };
    dataSource = {
      createQueryRunner: jest.fn(),
    };

    // Mock QueryRunner chain
    const mockQueryRunner = {
      connect: jest.fn().mockResolvedValue(undefined),
      startTransaction: jest.fn().mockResolvedValue(undefined),
      manager: {
        query: jest.fn(),
        find: jest.fn(),
        create: jest.fn(),
        save: jest.fn(),
        createQueryBuilder: jest.fn().mockReturnValue({
          delete: jest.fn().mockReturnThis(),
          from: jest.fn().mockReturnThis(),
          where: jest.fn().mockReturnThis(),
          andWhere: jest.fn().mockReturnThis(),
          execute: jest.fn().mockResolvedValue(undefined),
        }),
      },
      commitTransaction: jest.fn().mockResolvedValue(undefined),
      rollbackTransaction: jest.fn().mockResolvedValue(undefined),
      release: jest.fn().mockResolvedValue(undefined),
    };
    (dataSource.createQueryRunner as jest.Mock).mockReturnValue(mockQueryRunner);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrderCheckoutService,
        { provide: getRepositoryToken(CartEntity), useValue: cartRepo },
        { provide: getRepositoryToken(AddressEntity), useValue: addressRepo },
        { provide: DataSource, useValue: dataSource },
        {
          provide: 'CartService',
          useValue: { getTemplate: jest.fn(), calculateDiscount: jest.fn() },
        },
        {
          provide: 'CouponService',
          useValue: { getTemplate: jest.fn(), calculateDiscount: jest.fn(() => 0) },
        },
        {
          provide: 'PinoLogger',
          useValue: { setContext: jest.fn(), info: jest.fn() },
        },
        {
          provide: getRepositoryToken('UserCouponEntity'), // 如果需要
          useValue: {},
        },
      ],
    }).compile();

    service = module.get<OrderCheckoutService>(OrderCheckoutService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should throw CART_EMPTY when cart has no items', async () => {
    cartRepo.find!.mockResolvedValue([]);

    await expect(service.create(1, {} as any)).rejects.toEqual(
      expect.objectContaining({
        response: expect.objectContaining({
          code: ErrorCode.CART_EMPTY,
        }),
      }),
    );
  });
});
```

- [ ] **Step 2: 运行测试**

Run: `pnpm test:unit -- src/modules/order/order-checkout.service.spec.ts`
Expected: ≥ 1 test passed（空购物车场景）

- [ ] **Step 3: Commit**

```bash
git add packages/server/src/modules/order/order-checkout.service.spec.ts
git commit -m "test(order): add unit tests for checkout flow"
```

---

### Task 11: Web API Client 单元测试

Blocking: Task 3
Slice type: tracer-bullet
Seam: ≥ 2 个测试用例通过

**Files:**

- Create: `packages/web/src/api/client.spec.ts`

- [ ] **Step 1: 创建 `client.spec.ts`**

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import axios from 'axios';
import { apiClient } from './client';

// Mock axios
vi.mock('axios', () => {
  const mockAxiosInstance = {
    interceptors: {
      request: { use: vi.fn() },
      response: { use: vi.fn() },
    },
    defaults: { headers: { common: {} } },
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  };
  return {
    default: mockAxiosInstance,
    create: vi.fn(() => mockAxiosInstance),
  };
});

// Mock auth store
vi.mock('@/store/auth.store', () => ({
  useAuthStore: vi.fn(() => ({
    getState: vi.fn(() => ({
      token: null,
      refreshToken: null,
      setToken: vi.fn(),
      setState: vi.fn(),
    })),
  })),
}));

describe('apiClient', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should be created with correct baseURL', () => {
    expect(apiClient.defaults.baseURL).toBe('/api');
    expect(apiClient.defaults.timeout).toBe(15000);
  });

  it('should have request interceptor attached', () => {
    // 验证请求拦截器已注册
    expect(apiClient.interceptors.request.use).toHaveBeenCalled();
  });

  it('should have response interceptor attached', () => {
    // 验证响应拦截器已注册
    expect(apiClient.interceptors.response.use).toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: 运行测试**

Run (packages/web): `pnpm test:unit -- src/api/client.spec.ts`
Expected: ≥ 2 tests passed

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/api/client.spec.ts
git commit -m "test(web): add unit tests for API client interceptors"
```

---

### Task 12: 最终验证

Blocking: Task 1-11 全部完成
Slice type: verification
Seam: 所有 DoD 准则满足

- [ ] **Step 1: 格式化全项目**

Run (根目录): `pnpm format`
Expected: 成功格式化所有文件

- [ ] **Step 2: Lint 检查**

Run: `pnpm lint`
Expected: exit code 0（或仅有 warning）

- [ ] **Step 3: 运行全部单元测试**

Run: `pnpm test:unit`
Expected: server ≥ 8 tests passed, web ≥ 2 tests passed

- [ ] **Step 4: 验证 order.service.ts 行数**

Run: `wc -l packages/server/src/modules/order/order.service.ts`
Expected: ≤ 150

- [ ] **Step 5: 验证数据库索引**

Run: `grep -r "@Index" packages/server/src/entities/ | wc -l`
Expected: ≥ 8 个匹配

- [ ] **Step 6: 验证安全加固项**

Run: `grep "DB_SYNC" packages/server/src/config/database.config.ts | head -1`
Expected: 存在环境变量读取逻辑

Run: `grep "/^Bearer\\s+" packages/server/src/modules/auth/auth.controller.ts`
Expected: 存在正则匹配

Run: `grep "CORS_ORIGINS" packages/server/src/main.ts`
Expected: 存在环境变量读取

Run: `grep "your-jwt-secret-change-in-prod" packages/server/src/modules/auth/auth.service.ts`
Expected: 存在校验逻辑

- [ ] **Step 7: E2E 测试（若有 Docker 环境）**

Run: `docker compose up -d && pnpm test:e2e`
Expected: 全部通过（若无 Docker 则标记为待验证）

- [ ] **Step 8: Final commit（如有遗漏的 format fix）**

```bash
git add -A
git commit -m "chore: apply auto-format fixes from toolchain"
```

---

## 文件结构总览

```
demo/fruit-shop/
├── eslint.config.js                          # [Task 1 新建]
├── .prettierrc                               # [Task 1 新建]
├── .prettierignore                           # [Task 1 新建]
├── .editorconfig                             # [Task 1 新建]
├── package.json                              # [Task 1 修改]
├── packages/
│   ├── server/
│   │   ├── jest.unit.config.ts               # [Task 2 新建]
│   │   ├── package.json                      # [Task 2 修改]
│   │   ├── src/
│   │   │   ├── config/database.config.ts     # [Task 7 修改]
│   │   │   ├── main.ts                       # [Task 7 修改]
│   │   │   ├── entities/
│   │   │   │   ├── cart.entity.ts            # [Task 6 修改]
│   │   │   │   ├── order.entity.ts           # [Task 6 修改]
│   │   │   │   ├── order-item.entity.ts      # [Task 6 修改]
│   │   │   │   ├── review.entity.ts          # [Task 6 修改]
│   │   │   │   ├── favorite.entity.ts        # [Task 6 修改]
│   │   │   │   └── coupon-template.entity.ts # [Task 6 修改]
│   │   │   └── modules/
│   │   │       ├── auth/
│   │   │       │   ├── auth.service.ts       # [Task 7 修改]
│   │   │       │   ├── auth.controller.ts    # [Task 7 修改]
│   │   │       │   └── auth.service.spec.ts  # [Task 8 新建]
│   │   │       ├── cart/
│   │   │       │   └── cart.service.spec.ts  # [Task 9 新建]
│   │   │       └── order/
│   │   │           ├── order.module.ts       # [Task 5 修改]
│   │   │           ├── order.service.ts      # [Task 4 修改]
│   │   │           ├── order-checkout.service.ts         # [Task 4 新建]
│   │   │           ├── order-lifecycle.service.ts       # [Task 5 新建]
│   │   │           └── order-checkout.service.spec.ts   # [Task 10 新建]
│   └── web/
│       ├── package.json                      # [Task 3 修改]
│       ├── vite.config.ts                    # [Task 3 修改]
│       └── src/
│           ├── test-setup.ts                 # [Task 3 新建]
│           └── api/
│               └── client.spec.ts            # [Task 11 新建]
```

## 依赖关系图

```
Task 1 (ESLint+Prettier) ──────────────┬──→ Task 4 (OrderCheckoutService)
                                       │
Task 2 (Jest Unit Config) ─────────────┼──→ Task 8 (Auth Tests)
                                       │       │
Task 3 (Vitest Config) ───────────────┼──→ Task 11 (Web Client Tests)
                                       │
Task 6 (Indexes) ──────────────────────┤ (独立)
                                       │
Task 7 (Security) ─────────────────────┤ (独立)
                                       │
Task 5 (OrderLifecycleService) ◄──────┘ Task 4
                                       │
Task 9 (Cart Tests) ◄──────────────────┘ Task 2
                                       │
Task 10 (Checkout Tests) ◄─────────────┘ Task 4 + Task 8
                                       │
Task 12 (Final Verification) ◄──────────┘ 全部
```

**并行机会：** Task 1/2/3/6/7 彼此独立，可并行 dispatch（SDD Fan-Out）。
