---
spec_topic: fruit-shop-code-quality
decision_summary: '为 demo/fruit-shop 引入 ESLint + Prettier + 单元测试框架，拆分 Order Service，补齐数据库索引并加固安全配置——保守改动、学习导向'
design_approved: true
user_approved_at: 2026-07-24T12:00:00+08:00
gates: [user-review-pending]
---

# 鲜果集 (Fruit Shop) — 代码质量优化设计

> **日期**: 2026-07-24
> **定位**: Demo 项目代码质量基线建设，以学习为目的，保守改动（不引入 runtime 依赖、不重构架构）
> **范围**: 工具链配置 + 核心代码治理 + 示例测试

## 1. 背景与现状

`demo/fruit-shop` 是 agent-harness 的示例全栈电商项目（NestJS 10 + React 18 + TypeORM）。当前状态：

| 维度         | 现状                    | 问题                                      |
| ------------ | ----------------------- | ----------------------------------------- |
| Lint         | 无                      | 无法在开发阶段捕获代码问题                |
| Format       | 无                      | 团队协作时风格不一致                      |
| 单元测试     | 仅 e2e                  | 核心业务逻辑无快速反馈机制                |
| Service 规模 | order.service.ts 567 行 | 职责混合（下单 + 状态流转），可维护性下降 |
| 数据库索引   | 仅 address 表有完整索引 | 高频查询表全表扫描风险                    |
| 安全配置     | 硬编码默认值 / 宽松策略 | 生产部署隐患                              |

## 2. 方案概述

采用**渐进式改进策略**，分三个 Phase 执行：

```
Phase 1: 工具链基础设施   → 零回归风险，纯配置文件
Phase 2: 代码治理          → 拆分大 service + 索引 + 安全加固
Phase 3: 示例测试          → 核心路径单元测试覆盖
```

## 3. Phase 1：工具链基础设施

### 3.1 ESLint（Flat Config）

根目录新建 `eslint.config.js`，使用 ESLint 9+ flat config 格式：

```javascript
// eslint.config.js
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

**依赖清单**（devDependencies）：

- `eslint`, `@eslint/js`
- `typescript-eslint`, `@typescript-eslint/parser`, `@typescript-eslint/eslint-plugin`
- `eslint-plugin-react`
- `eslint-config-prettier`
- `eslint-plugin-nestjs`（server 端可选扩展规则）

### 3.2 Prettier

```json
// .prettierrc
{
  "semi": true,
  "singleQuote": true,
  "printWidth": 100,
  "trailingComma": "all",
  "tabWidth": 2,
  "endOfLine": "lf"
}
```

`.prettierignore`:

```
dist/
node_modules/
coverage/
pnpm-lock.yaml
packages/server/uploads/
```

### 3.3 package.json 脚本更新

```json
{
  "scripts": {
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "test:unit": "pnpm -r run test:unit",
    "test:e2e": "jest --config packages/server/test/jest-e2e.config.ts"
  }
}
```

### 3.4 单元测试框架

**Server 端** — Jest（复用现有）：

- 新建 `packages/server/jest.unit.config.ts`：
  - 不连接测试数据库（mock TypeORM DataSource / Repository）
  - 使用 `@golevelup/ts-jest` 的自动 mock 能力
  - `testMatch`: `**/*.spec.ts`

**Web 端** — Vitest（与 Vite 原生集成）：

- `packages/web/package.json` 添加：`vitest`, `@testing-library/react`, `@testing-library/jest-dom`, `jsdom`
- `vite.config.ts` 添加 `/// <reference types="vitest" />` + `test: {}` 配置块

### 3.5 EditorConfig

```ini
# .editorconfig
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

## 4. Phase 2：代码治理

### 4.1 Order Service 拆分（Facade 模式）

**动机**：`order.service.ts` 567 行混合了两个独立职责域。

**拆分后结构**：

```
packages/server/src/modules/order/
├── order.module.ts              # 注册 OrderCheckoutService + OrderLifecycleService
├── order.controller.ts           # 不变
├── order.service.ts              # Facade：getList/getDetail/统计 + 委托
├── order-checkout.service.ts     # 下单逻辑：create/validateCart/calculateTotal/deductStock/applyCoupon
└── order-lifecycle.service.ts    # 状态流转：cancel/pay/ship/confirm/refund
```

**Facade 委托模式**：

```typescript
// order.service.ts（瘦身后）
@Injectable()
export class OrderService {
  constructor(
    private readonly checkoutService: OrderCheckoutService,
    private readonly lifecycleService: OrderLifecycleService,
  ) {}

  async create(userId: string, dto: CreateOrderDto) {
    return this.checkoutService.create(userId, dto);
  }

  async cancel(orderId: string, userId: string) {
    return this.lifecycleService.cancel(orderId, userId);
  }
  // getList/getDetail/stats 保留在此 service 中
}
```

**不变更**：

- Controller 方法签名和调用方式
- API 路由和请求/响应格式
- E2E 测试应全部通过

### 4.2 数据库索引

在以下 Entity 文件中添加 `@Index()` 装饰器（纯添加，无破坏性）：

| Entity           | 索引列                                      | 查询场景                |
| ---------------- | ------------------------------------------- | ----------------------- |
| `Cart`           | `userId`                                    | 按 user 查购物车        |
| `Order`          | `userId`, `status`                          | 订单列表筛选            |
| `OrderItem`      | `orderId`（显式声明）                       | 订单明细查询            |
| `Review`         | `productId`, `userId`                       | 商品评论 / 用户评论历史 |
| `Favorite`       | `userId`, `productId`                       | 收藏列表 / 重复收藏判断 |
| `CouponTemplate` | `['status', 'startAt', 'endTime']` 复合索引 | 可用优惠券列表          |

### 4.3 安全加固（4 项）

#### 4.3.1 synchronize 环境化

**文件**: `packages/server/src/config/database.config.ts`

```typescript
// 改动前
synchronize: true,

// 改动后
synchronize: process.env.DB_SYNC !== 'false',
```

启动校验（可在 `main.ts` 或 database config 中）：

- 若 `NODE_ENV === 'production'` 且 `DB_SYNC !== 'false'` → console warning 或抛异常

#### 4.3.2 Token 解析标准化

**文件**: `packages/server/src/modules/auth/auth.controller.ts`

```typescript
// 改动前
const token = authHeader.replace('Bearer ', '');

// 改动后
const match = authHeader.match(/^Bearer\s+(.+)$/i);
const token = match?.[1] ?? '';
```

#### 4.3.3 CORS 可配置

**文件**: `packages/server/src/main.ts`

```typescript
// 改动前
app.enableCors({ origin: true, credentials: true });

// 改动后
const corsOrigins = process.env.CORS_ORIGINS;
app.enableCors({
  origin: corsOrigins ? corsOrigins.split(',') : true,
  credentials: true,
});
```

#### 4.3.4 JWT Secret 启动校验

**文件**: `packages/server/src/modules/auth/auth.service.ts`

在 `OnModuleInit` 或构造函数中检查：

- 检测到默认 secret 值（如 `your-jwt-secret-change-in-prod`）时：
  - 开发环境 → console warning
  - 生产环境 → 抛异常，拒绝启动

## 5. Phase 3：示例测试

为以下模块各编写 2-3 个核心路径的单元测试：

### 5.1 Server 端（Jest + @golevelup/ts-jest）

| 文件                             | 覆盖场景                                               |
| -------------------------------- | ------------------------------------------------------ |
| `auth.service.spec.ts`           | 注册成功 / 用户名重复冲突 / 登录成功 / 密码错误        |
| `cart.service.spec.ts`           | 添加商品（存在） / 添加商品（不存在报错） / 清空购物车 |
| `order-checkout.service.spec.ts` | 创建订单成功 / 库存不足回滚 / 购物车为空               |

Mock 策略：

- TypeORM Repository → 用 `jest.mock()` 自动 mock
- Redis → mock `RedisService` 的 `set/get` 方法
- JwtService → mock `signAsync/verifyAsync`

### 5.2 Web 端（Vitest + Testing Library）

| 文件                 | 覆盖场景                                                             |
| -------------------- | -------------------------------------------------------------------- |
| `api/client.spec.ts` | 请求拦截器附加 token / 401 触发 refresh / refresh 成功后重放排队请求 |

## 6. 执行顺序与验证

```
1. Phase 1 配置文件创建
   └─ 验证：pnpm lint / pnpm format:check 能正常运行（允许有 error，但不能 crash）

2. Phase 1 依赖安装
   └─ 验证：pnpm install 成功

3. Phase 2 Order Service 拆分
   └─ 验证：现有 e2e 测试全部通过

4. Phase 2 索引 + 安全加固
   └─ 验证：服务正常启动，API 行为不变

5. Phase 3 示例测试
   └─ 验证：pnpm test:unit 全部通过
```

## 7. 不涉及的内容

- 不新增 runtime 运行时依赖
- 不改前端组件/页面/UI
- 不改路由定义或 API 契约
- 不改数据库 schema（仅加索引，不改列）
- 不改 docker-compose.yml 结构
- 不做大规模重构（仅 order service 一个 facade 拆分）

## 8. 学习价值总结

通过本次优化可实践的知识点：

| 领域     | 知识点                                                 |
| -------- | ------------------------------------------------------ |
| 工程化   | ESLint flat config、Prettier 集成、EditorConfig        |
| 测试     | NestJS 单元测试（mock 策略）、Vitest + Testing Library |
| 架构     | Facade 模式、Service 职责拆分边界                      |
| 数据库   | TypeORM 索引策略、复合索引设计                         |
| 安全     | 环境变量化配置、启动时安全校验模式                     |
| Monorepo | pnpm workspace 下多包工具链统一                        |
