import { apiClient } from './client';
import type { ApiResponse, LoginDTO, RegisterDTO, LoginResponse } from 'shared';

export const authApi = {
  login(data: LoginDTO) {
    return apiClient.post<ApiResponse<LoginResponse>>('/auth/login', data);
  },

  register(data: RegisterDTO) {
    return apiClient.post<ApiResponse<LoginResponse>>('/auth/register', data);
  },

  refresh(refreshToken: string) {
    return apiClient.post<ApiResponse<{ token: string }>>('/auth/refresh', {
      refreshToken,
    });
  },

  logout() {
    return apiClient.post<ApiResponse<null>>('/auth/logout');
  },
};
