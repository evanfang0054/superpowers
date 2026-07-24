export interface Review {
  id: number;
  productId: number;
  userId: number;
  orderId: number;
  rating: number; // 1-5
  content: string;
  images: string[] | null;
  createdAt: string;
  updatedAt: string;
}

export interface ReviewWithUser extends Review {
  userNickname: string | null;
  userAvatar: string | null;
}

export interface CreateReviewItemDTO {
  productId: number;
  rating: number;
  content: string;
  images?: string[];
}

export interface CreateReviewDTO {
  reviews: CreateReviewItemDTO[];
}
