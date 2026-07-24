import { apiClient } from './client';
import type { ApiResponse, Address, CreateAddressDTO, UpdateAddressDTO } from 'shared';

export const addressApi = {
  getList() {
    return apiClient.get<ApiResponse<Address[]>>('/addresses');
  },

  create(data: CreateAddressDTO) {
    return apiClient.post<ApiResponse<Address>>('/addresses', data);
  },

  update(id: number, data: UpdateAddressDTO) {
    return apiClient.put<ApiResponse<Address>>(`/addresses/${id}`, data);
  },

  remove(id: number) {
    return apiClient.delete<ApiResponse<void>>(`/addresses/${id}`);
  },

  setDefault(id: number) {
    return apiClient.put<ApiResponse<Address>>(`/addresses/${id}/default`);
  },
};
