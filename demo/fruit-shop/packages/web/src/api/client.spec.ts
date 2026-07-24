import { describe, it, expect, vi } from 'vitest';
import { apiClient } from './client';

// Mock axios with a create function that captures the config onto the instance
vi.mock('axios', () => {
  const defaults: Record<string, unknown> = { headers: { common: {} } };

  const mockAxiosInstance = {
    defaults,
    interceptors: {
      request: { use: vi.fn() },
      response: { use: vi.fn() },
    },
  };

  const mockCreate = vi.fn((config: Record<string, unknown>) => {
    Object.assign(defaults, config);
    return mockAxiosInstance;
  });

  return {
    default: { ...mockAxiosInstance, create: mockCreate },
    create: mockCreate,
  };
});

// Mock auth store — client.ts uses useAuthStore.getState() directly
// (not as a React hook), so the mock must have getState as a property.
vi.mock('@/store/auth.store', () => {
  const mockGetState = vi.fn(() => ({
    token: null,
    refreshToken: null,
    setToken: vi.fn(),
    setState: vi.fn(),
  }));

  return {
    useAuthStore: {
      getState: mockGetState,
      setState: vi.fn(),
    },
  };
});

describe('apiClient', () => {
  it('should be created with correct baseURL and timeout', () => {
    expect(apiClient.defaults.baseURL).toBe('/api');
    expect(apiClient.defaults.timeout).toBe(15000);
  });

  it('should have request interceptor attached', () => {
    expect(apiClient.interceptors.request.use).toHaveBeenCalled();
  });

  it('should have response interceptor attached', () => {
    expect(apiClient.interceptors.response.use).toHaveBeenCalled();
  });
});
