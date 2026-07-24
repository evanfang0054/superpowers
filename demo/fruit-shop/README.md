# 鲜果集 — 新鲜水果产地直发

一个全栈水果电商平台，包含用户浏览、购物车、下单、订单管理等完整购物流程，以及管理员商品管理功能。

## 技术栈

| 层级       | 技术                                                                         |
| ---------- | ---------------------------------------------------------------------------- |
| **前端**   | React 18 + TypeScript + Vite 6 + Tailwind CSS v4 + Zustand + React Router v6 |
| **后端**   | NestJS 10 + TypeScript + TypeORM + Passport JWT                              |
| **数据库** | MySQL 8.0 + Redis 7                                                          |
| **部署**   | Docker + docker-compose + Nginx                                              |
| **共享**   | pnpm workspace monorepo，`shared` 包统一前后端类型                           |

## 项目结构

```
fruit-shop/
├── packages/
│   ├── shared/          # 共享类型、枚举、错误码
│   ├── server/          # NestJS 后端 API
│   └── web/             # React 前端 SPA
├── docker-compose.yml
└── pnpm-workspace.yaml
```

## 快速开始

### 环境要求

- Node.js >= 20.0.0
- pnpm >= 10.0.0
- MySQL 8.0
- Redis 7

### 本地开发

```bash
# 安装依赖
pnpm install

# 构建（按顺序：shared → server → web）
pnpm build

# 或者分别启动开发服务器
pnpm dev:shared    # 共享包 watch 模式
pnpm dev:server    # NestJS 后端 :3000
pnpm dev:web       # Vite 前端 :5173
```

后端启动前需配置环境变量：

```bash
cp packages/server/.env.example packages/server/.env.local
# 编辑 .env.local 填入实际的数据库和 Redis 连接信息
```

### Docker 部署

```bash
docker-compose up -d
```

启动后：

- 前端：`http://localhost`
- 后端 API：`http://localhost:3000/api`
- MySQL：`localhost:3306`（自动执行 `init.sql` 初始化表结构和种子数据）
- Redis：`localhost:6379`

## 环境变量

| 变量                     | 默认值       | 说明                                    |
| ------------------------ | ------------ | --------------------------------------- |
| `DB_HOST`                | `localhost`  | MySQL 主机                              |
| `DB_PORT`                | `3306`       | MySQL 端口                              |
| `DB_USERNAME`            | `root`       | MySQL 用户名                            |
| `DB_PASSWORD`            | `root123`    | MySQL 密码                              |
| `DB_DATABASE`            | `fruit_shop` | 数据库名                                |
| `REDIS_HOST`             | `localhost`  | Redis 主机                              |
| `REDIS_PORT`             | `6379`       | Redis 端口                              |
| `JWT_SECRET`             | —            | JWT 签名密钥（生产环境务必修改）        |
| `JWT_ACCESS_EXPIRES_IN`  | `900`        | Access Token 有效期（秒，默认 15 分钟） |
| `JWT_REFRESH_EXPIRES_IN` | `604800`     | Refresh Token 有效期（秒，默认 7 天）   |
| `PORT`                   | `3000`       | 服务端口                                |

## API 接口

所有接口前缀 `/api`，统一响应格式：

```json
{ "code": 0, "data": {}, "message": "success" }
```

### 认证 `/api/auth`

| 方法 | 路径             | 权限 | 说明               |
| ---- | ---------------- | ---- | ------------------ |
| POST | `/auth/register` | 公开 | 注册               |
| POST | `/auth/login`    | 公开 | 登录，返回双令牌   |
| POST | `/auth/refresh`  | 公开 | 刷新 Access Token  |
| POST | `/auth/logout`   | 登录 | 登出，黑名单 Token |

### 用户 `/api/user`

| 方法 | 路径            | 权限 | 说明         |
| ---- | --------------- | ---- | ------------ |
| GET  | `/user/profile` | 登录 | 获取个人信息 |
| PUT  | `/user/profile` | 登录 | 更新个人信息 |

### 商品 `/api/products`

| 方法   | 路径            | 权限   | 说明                   |
| ------ | --------------- | ------ | ---------------------- |
| GET    | `/products`     | 公开   | 商品列表（分页、筛选） |
| GET    | `/products/:id` | 公开   | 商品详情               |
| POST   | `/products`     | 管理员 | 创建商品               |
| PUT    | `/products/:id` | 管理员 | 更新商品               |
| DELETE | `/products/:id` | 管理员 | 删除商品               |

### 分类 `/api/categories`

| 方法 | 路径          | 权限 | 说明     |
| ---- | ------------- | ---- | -------- |
| GET  | `/categories` | 公开 | 分类列表 |

### 购物车 `/api/cart`

| 方法   | 路径        | 权限 | 说明         |
| ------ | ----------- | ---- | ------------ |
| GET    | `/cart`     | 登录 | 购物车列表   |
| POST   | `/cart`     | 登录 | 添加到购物车 |
| PUT    | `/cart/:id` | 登录 | 更新数量     |
| DELETE | `/cart/:id` | 登录 | 删除购物车项 |

### 订单 `/api/orders`

| 方法 | 路径                 | 权限 | 说明             |
| ---- | -------------------- | ---- | ---------------- |
| POST | `/orders`            | 登录 | 创建订单（事务） |
| GET  | `/orders`            | 登录 | 订单列表（分页） |
| GET  | `/orders/:id`        | 登录 | 订单详情         |
| PUT  | `/orders/:id/cancel` | 登录 | 取消订单         |

## 前端页面

| 路由              | 页面          | 说明                           |
| ----------------- | ------------- | ------------------------------ |
| `/`               | Home          | 首页，商品分类浏览、搜索       |
| `/product/:id`    | ProductDetail | 商品详情、规格选择、加购       |
| `/login`          | Login         | 手机号 + 密码登录              |
| `/register`       | Register      | 注册新账号                     |
| `/cart`           | Cart          | 购物车（需登录）               |
| `/checkout`       | Checkout      | 结算下单（需登录）             |
| `/orders`         | OrderList     | 订单列表，按状态筛选（需登录） |
| `/order/:id`      | OrderDetail   | 订单详情，可取消（需登录）     |
| `/admin/products` | AdminProducts | 商品管理 CRUD（需管理员）      |

## 数据库

共 6 张表，由 `packages/server/init.sql` 自动初始化：

| 表            | 说明     | 种子数据                                |
| ------------- | -------- | --------------------------------------- |
| `users`       | 用户     | —                                       |
| `categories`  | 分类     | 5 条（热带/浆果/柑橘/进口/精选）        |
| `products`    | 商品     | 6 条（芒果/草莓/车厘子/蓝莓/脐橙/山竹） |
| `carts`       | 购物车   | —                                       |
| `orders`      | 订单     | —                                       |
| `order_items` | 订单明细 | —                                       |

## 认证机制

- **双令牌**：Access Token（15 分钟）+ Refresh Token（7 天）
- **黑名单**：登出时将 Token 加入 Redis 黑名单
- **自动续期**：前端 Axios 拦截器在 401 时自动刷新 Token
- **首用户管理员**：注册的第一个用户自动获得 `admin` 角色
- **角色控制**：`@Roles(UserRole.ADMIN)` 装饰器保护管理员接口

## 构建部署

```bash
# 顺序构建全部
pnpm build

# Docker 一键部署
docker-compose up -d --build
```

前端由 Nginx 托管静态文件，未匹配路由 fallback 到 `index.html`（SPA 模式）。API 请求通过 Nginx 反向代理到后端服务。
