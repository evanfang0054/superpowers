# Sprint Contract: DESIGN.md 全面对齐修复

## Definition of Done

- [ ] `index.html` Google Fonts 加载 `Fredoka:800` 和 `Noto+Sans+SC:900`
- [ ] `index.css` `@theme` 块包含 6 个 `--radius-*` + 3 个 `--gradient-*` 语义变量
- [ ] 所有 SVG stroke 硬编码色值替换为 `currentColor`，父元素用 brand token class 控色
- [ ] 所有内联渐变（BuyBar、PromoBanner、Description）替换为 CSS 变量引用
- [ ] 所有组件中的硬编码 hex 替换为 `var(--color-brand-*)`；带透明度的色值用 `color-mix(in srgb, var(...) X%, transparent)` 方案
- [ ] PriceSection Tag `rounded-[20px]` → `rounded-full`
- [ ] Toast 4 个变体色迁移到 brand token + 圆角 `rounded-2xl`
- [ ] LoadingSpinner `var(--color-primary)` → `var(--color-brand-primary)`
- [ ] 7 个旧页面完成旧→新 token 全量替换
- [ ] `pnpm build` 无错误，`pnpm dev` 正常启动
- [ ] `grep -r 'bg-primary\|text-primary\|bg-success\|bg-danger\|bg-warning\|bg-info\|text-success\|text-danger\|text-warning\|text-info\|hover:text-danger\|hover:bg-danger\|bg-gray-50' packages/web/src/ --include='*.tsx'` 返回 0 结果（旧 token 在 tsx 中无残留）
- [ ] Home / ProductDetail 页面视觉无变化（新旧 token 值相同，不引入回归）

## Boundary Conditions

- 必须支持：双 token 定义在 `index.css` 中共存（旧定义保留但不被引用）
- 不得破坏：Home / ProductDetail 已对齐页面的视觉和功能
- 不修改：组件结构和功能逻辑、`ProductCard.tsx` 的动态 color 拼接
- 性能：无性能回退（仅 CSS 变量替换）

## Acceptance Criteria

- Computational: `pnpm build` exit code 0；grep 旧 token 在 `.tsx` 文件中返回 0 匹配
- Inferential: 逐文件 diff 审查确认每个改动对应 spec 中的具体条目

## Negotiation Record

- Generator: 初始 10 条 DoD，编译验证只写"正常编译和启动"
- Evaluator: 挑战 — hex+透明度替换方案需验证、编译验证太宽泛、缺少旧 token 残留检查、缺少批量验证手段
- Final consensus: 修订版 12 条 DoD，含 grep 批量验证、明确 `pnpm build` + `pnpm dev`、确认 Home/ProductDetail 无回归
