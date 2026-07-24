import { apiClient } from './client';
import type { ApiResponse, PaginatedResponse, Product, Category, PaginationQuery } from 'shared';

export interface ProductQuery extends PaginationQuery {
  categoryId?: number;
  keyword?: string;
  status?: string;
}

export const productApi = {
  getList(params?: ProductQuery) {
    return apiClient.get<ApiResponse<PaginatedResponse<Product>>>('/products', { params });
  },

  getDetail(id: number) {
    return apiClient.get<ApiResponse<Product>>(`/products/${id}`);
  },

  getRecommendations(limit = 10) {
    return apiClient.get<ApiResponse<Product[]>>('/products/recommendations', {
      params: { limit },
    });
  },

  getCategories() {
    return apiClient.get<ApiResponse<Category[]>>('/categories');
  },

  getBestsellers(limit = 10) {
    return apiClient.get<ApiResponse<{ list: Product[] }>>('/products/bestsellers', {
      params: { limit },
    });
  },

  suggest(keyword: string, limit = 10) {
    return apiClient.get<ApiResponse<{ list: string[] }>>('/products/suggest', {
      params: { keyword, limit },
    });
  },
};
