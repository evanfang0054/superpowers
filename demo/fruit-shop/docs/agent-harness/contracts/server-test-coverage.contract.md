# Sprint Contract: 后端测试全量补齐

- 日期：2026-06-19
- 关联 Spec：`docs/agent-harness/specs/2026-06-19-server-test-coverage-design.md`

## Definition of Done

- [ ] **单测文件齐全**：新增 10 个 spec 文件，路径与 spec 第 3 节「文件结构」逐项对应
  - `src/modules/auth/auth.service.spec.ts`
  - `src/modules/auth/jwt.strategy.spec.ts`
  - `src/modules/user/user.service.spec.ts`
  - `src/modules/product/product.service.spec.ts`
  - `src/modules/cart/cart.service.spec.ts`
  - `src/modules/order/order.service.spec.ts`
  - `src/common/guards/jwt-auth.guard.spec.ts`
  - `src/common/guards/roles.guard.spec.ts`
  - `src/common/interceptors/transform.interceptor.spec.ts`
  - `src/common/filters/http-exception.filter.spec.ts`
- [ ] **单测用例数达标**（见附录 A）：每个 spec 文件的 `it()` 数量 ≥ 附录 A 给出的下限
- [ ] **e2e 用例数达标**（见附录 A）：每个 e2e 文件新增 `it()` 数量 ≥ 附录 A 给出的下限
- [ ] **TestHelper 扩展**：`createProductAsAdmin` 与 `addToCartAsUser` 方法存在且被 e2e 使用
- [ ] **现有测试不回归**：原 6 个 controller spec + 原 e2e happy path 用例全部继续通过
- [ ] **全绿验证**：
  - `pnpm --filter server test:unit` 退出码 0（不依赖真实 DB/Redis）
  - `pnpm --filter server test:e2e` 退出码 0（依赖本地 docker compose 起的 mysql+redis）
- [ ] **不引入新依赖**：`packages/server/package.json` 的 dependencies 与 devDependencies 均不增加
- [ ] **业务代码变更规则**：默认不改业务代码；若测试发现真实 bug，**停下来与用户确认**后再修，并在交付说明中单列

## Boundary Conditions

- **单测**：纯 mock，零真实 DB/Redis 依赖，可并行执行
- **e2e**：依赖 `fruit_shop_test` 库 + `REDIS_DB=1`；执行前需 `docker compose up -d mysql redis` + `pnpm --filter shared build`
- **e2e 限流**：新增 auth e2e 用例必须在 Rate limiting 测试之前执行（文件内顺序），或使用独立手机号，**不允许出现 flaky**

## Acceptance Criteria

- **Computational（传感器）**：
  - `pnpm --filter server test:unit` 退出码 = 0
  - `pnpm --filter server test:e2e` 退出码 = 0
  - 新增单测文件数 = 10（Glob 校验）
  - 每个新增 spec 文件的 `it(/it(`/test( 出现次数 ≥ 附录 A 下限（grep 校验）
- **Inferential（人工评审）**：
  - 用户 review 测试 diff
  - 用户确认两份 jest 输出（unit + e2e）

## 附录 A：用例数下限

### 单测（新增文件）

| 文件                          | it() 下限 |
| ----------------------------- | --------- |
| auth.service.spec.ts          | 14        |
| user.service.spec.ts          | 4         |
| product.service.spec.ts       | 12        |
| cart.service.spec.ts          | 9         |
| order.service.spec.ts         | 10        |
| jwt.strategy.spec.ts          | 3         |
| jwt-auth.guard.spec.ts        | 5         |
| roles.guard.spec.ts           | 4         |
| transform.interceptor.spec.ts | 3         |
| http-exception.filter.spec.ts | 7         |

### e2e（扩写文件，新增用例）

| 文件                | 新增 it() 下限 |
| ------------------- | -------------- |
| auth.e2e-spec.ts    | 3              |
| product.e2e-spec.ts | 6              |
| cart.e2e-spec.ts    | 4              |
| order.e2e-spec.ts   | 4              |
| user.e2e-spec.ts    | 3              |

## Negotiation Record

- **Generator R1**：初稿以「文件数 + 全绿 + 覆盖 spec 分支」作为 DoD。
- **Evaluator R2 挑战**：
  - C1 文件数不等于用例覆盖深度
  - C2 「覆盖 spec 分支」缺少可验证手段
  - C3 「不改业务代码」与「发现 bug 停下」冲突未澄清
  - C4 「贴输出」不是可验证 DoD
  - C5 现有测试回归风险未列入
  - C6 限流 flaky 风险只在 spec 提及未入契约
  - C7 e2e 新增用例数不明确
- **Generator R3 修订**：用例数转精确数字（附录 A）；业务代码变更规则改为「停下确认」；新增「现有测试不回归」；限流 flaky 进 Boundary；自测输出改为「用户确认」。
- **Evaluator R4**：接受。要求附录 A 写入契约文件本身以防漂移 → 已纳入。
- **Final consensus**：本文件版本。
