# Sprint Contract: fruit-shop-code-quality

## Definition of Done

- [ ] **D1**: `pnpm lint` 对 `packages/server/src/` 和 `packages/web/src/` 执行 exit code 0
- [ ] **D2**: `pnpm format` 首次格式化全项目成功；之后 `format:check` 零差异
- [ ] **D3**: `pnpm test:unit` 全部通过：server ≥ 8 个测试, web ≥ 2 个测试
- [ ] **D4**: `order.service.ts` ≤ 150 行（checkout/lifecycle 提取为独立 service）
- [ ] **D5**: Cart/Order/OrderItem/Review/Favorite/CouponTemplate 共 6 张 Entity 新增 `@Index()`
- [ ] **D6**: `synchronize` 读 `DB_SYNC` 环境变量，prod 模式非 `false` 时 warning
- [ ] **D7**: Token 解析使用 `/^Bearer\s+(.+)$/i` 正则
- [ ] **D8**: CORS 读 `CORS_ORIGINS` 环境变量；JWT secret 为默认值时 prod 抛异常
- [ ] **D9**: 现有 e2e 测试全部通过（需 Docker 环境；无 Docker 时标记为待验证）

## Boundary Conditions

- **Must support**: Node >= 20, pnpm >= 10, 现有 Docker 开发环境
- **Must not break**: API 契约、路由、前端页面功能、现有 e2e 测试
- **Performance**: 不引入性能回归（索引添加只增不减）
- **Dependencies**: 仅允许新增 devDependencies（ESLint/Prettier/Vitest/Testing Library 等）
- **Scope**: 不改前端组件/页面、不改 docker-compose.yml 结构、不改数据库 schema（仅加索引）

## Acceptance Criteria

- **Computational**: `pnpm lint && pnpm format:check && pnpm test:unit` 全部 exit code 0
- **Inferential**: Code review 确认 order.service 拆分后 controller 无感知、安全加固项均有对应环境变量读取

## Negotiation Record

- **Generator v1**: 9 条准则，含模糊描述（"可观察"）
- **Evaluator challenge**: D2 首次 vs 持续区分、D3 数量明确化、D6-D8 具体化、D9 环境依赖标注
- **Generator v2**: 上述修订版
- **Evaluator final**: 接受
