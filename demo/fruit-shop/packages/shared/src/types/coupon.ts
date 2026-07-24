export enum CouponType {
  FULL_REDUCTION = 0, // 满减
  DISCOUNT = 1, // 折扣
  NO_THRESHOLD = 2, // 无门槛
}

export interface CouponTemplate {
  id: number;
  name: string;
  type: CouponType;
  minAmount: number;
  discountAmount: number;
  discountRate: number | null;
  categoryId: number | null;
  totalCount: number;
  claimedCount: number;
  startAt: string;
  endAt: string;
  status: number;
  createdAt: string;
  updatedAt: string;
}

export interface UserCoupon {
  id: number;
  userId: number;
  couponId: number;
  orderId: number | null;
  usedAt: string | null;
  createdAt: string;
  coupon?: CouponTemplate;
}

export interface CreateCouponTemplateDTO {
  name: string;
  type: CouponType;
  minAmount?: number;
  discountAmount?: number;
  discountRate?: number;
  categoryId?: number;
  totalCount?: number;
  startAt: string;
  endAt: string;
  status?: number;
}

export type UpdateCouponTemplateDTO = Partial<CreateCouponTemplateDTO>;

export interface CouponPreviewRequest {
  couponId: number;
  items: Array<{ productId: number; quantity: number; price: number; categoryId?: number }>;
}

export interface CouponPreviewResponse {
  discountAmount: number;
  totalAfterDiscount: number;
}
