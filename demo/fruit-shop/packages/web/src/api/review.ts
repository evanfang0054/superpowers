import { apiClient } from './client';
import type {
  ApiResponse,
  PaginatedResponse,
  ReviewWithUser,
  CreateReviewDTO,
  PaginationQuery,
} from 'shared';

export const reviewApi = {
  getByProduct(productId: number, params?: PaginationQuery) {
    return apiClient.get<ApiResponse<PaginatedResponse<ReviewWithUser>>>(
      `/products/${productId}/reviews`,
      { params },
    );
  },

  createFromOrder(orderId: number, data: CreateReviewDTO) {
    return apiClient.post<ApiResponse<unknown>>(`/orders/${orderId}/reviews`, data);
  },

  getMine(params?: PaginationQuery) {
    return apiClient.get<ApiResponse<PaginatedResponse<ReviewWithUser>>>('/reviews/mine', {
      params,
    });
  },
};
