import { apiClient } from './client';
import type { ApiResponse, PaginatedResponse, Refund } from 'shared';

export const refundApi = {
  list(params?: { page?: number; limit?: number; status?: number }) {
    return apiClient.get<ApiResponse<PaginatedResponse<Refund>>>('/admin/refunds', { params });
  },
  approve(id: number) {
    return apiClient.post<ApiResponse<Refund>>(`/admin/refunds/${id}/approve`);
  },
  reject(id: number, adminNote: string) {
    return apiClient.post<ApiResponse<Refund>>(`/admin/refunds/${id}/reject`, {
      adminNote,
    });
  },
};
