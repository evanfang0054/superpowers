import { apiClient } from './client';
import type { ApiResponse, Banner, CreateBannerDTO, UpdateBannerDTO } from 'shared';

export const bannerApi = {
  getActive() {
    return apiClient.get<ApiResponse<Banner[]>>('/banners');
  },
  getAll() {
    return apiClient.get<ApiResponse<Banner[]>>('/banners/all');
  },
  create(data: CreateBannerDTO) {
    return apiClient.post<ApiResponse<Banner>>('/banners', data);
  },
  update(id: number, data: UpdateBannerDTO) {
    return apiClient.put<ApiResponse<Banner>>(`/banners/${id}`, data);
  },
  remove(id: number) {
    return apiClient.delete<ApiResponse<null>>(`/banners/${id}`);
  },
};
