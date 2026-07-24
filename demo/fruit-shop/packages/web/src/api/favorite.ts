import { apiClient } from './client';
import type { ApiResponse, PaginatedResponse, FavoriteWithProduct, PaginationQuery } from 'shared';

export const favoriteApi = {
  add(productId: number) {
    return apiClient.post<ApiResponse<unknown>>(`/products/${productId}/favorite`);
  },

  remove(productId: number) {
    return apiClient.delete<ApiResponse<unknown>>(`/products/${productId}/favorite`);
  },

  getList(params?: PaginationQuery) {
    return apiClient.get<ApiResponse<PaginatedResponse<FavoriteWithProduct>>>('/favorites', {
      params,
    });
  },

  getStatus(productId: number) {
    return apiClient.get<ApiResponse<{ favorited: boolean }>>(
      `/products/${productId}/favorite-status`,
    );
  },
};
