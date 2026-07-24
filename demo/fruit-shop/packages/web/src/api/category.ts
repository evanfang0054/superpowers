import { apiClient } from './client';
import type { ApiResponse, Category } from 'shared';

export const categoryApi = {
  getAll() {
    return apiClient.get<ApiResponse<Category[]>>('/categories');
  },
  create(data: { name: string; icon?: string; sortOrder?: number }) {
    return apiClient.post<ApiResponse<Category>>('/categories', data);
  },
  update(id: number, data: { name?: string; icon?: string; sortOrder?: number }) {
    return apiClient.put<ApiResponse<Category>>(`/categories/${id}`, data);
  },
  remove(id: number) {
    return apiClient.delete<ApiResponse<null>>(`/categories/${id}`);
  },
};
