export interface Shipping {
  id: number;
  orderId: number;
  company: string;
  trackingNo: string;
  shippedAt: string;
  status: number; // 0=运输中 1=已签收
  createdAt: string;
}
