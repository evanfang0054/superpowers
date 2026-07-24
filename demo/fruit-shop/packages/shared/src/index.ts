// Types
export type { Product, Category } from './types/product';
export { ProductStatus } from './types/product';

export type { User, LoginDTO, RegisterDTO, LoginResponse } from './types/user';
export { UserRole } from './types/user';

export type { CartItem, AddToCartDTO, UpdateCartDTO, CartItemWithProduct } from './types/cart';

export type { Order, OrderItem, CreateOrderDTO, OrderWithItems } from './types/order';
export { OrderStatus } from './types/order';

export type { ApiResponse, PaginatedResponse, PaginationQuery } from './types/api';

export type { ProductSpec } from './types/product';

export type { Banner, BannerLinkType, CreateBannerDTO, UpdateBannerDTO } from './types/banner';

export type { Address, CreateAddressDTO, UpdateAddressDTO } from './types/address';

export type { Review, ReviewWithUser, CreateReviewItemDTO, CreateReviewDTO } from './types/review';

export type { Favorite, FavoriteWithProduct } from './types/favorite';

export type {
  CouponTemplate,
  UserCoupon,
  CreateCouponTemplateDTO,
  UpdateCouponTemplateDTO,
  CouponPreviewRequest,
  CouponPreviewResponse,
} from './types/coupon';
export { CouponType } from './types/coupon';

export type { Shipping } from './types/shipping';

export type { Refund, CreateRefundDTO, ReviewRefundDTO } from './types/refund';
export { RefundStatus } from './types/refund';

// Constants
export { ErrorCode, ErrorMessage, SUCCESS_CODE } from './constants';
export type { ErrorCodeType } from './constants';
