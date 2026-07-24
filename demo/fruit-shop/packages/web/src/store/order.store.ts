import { create } from 'zustand';
import type { Order, OrderWithItems, CreateOrderDTO, PaginationQuery } from 'shared';
import { orderApi } from '@/api/order';

interface OrderState {
  orders: Order[];
  currentOrder: OrderWithItems | null;
  isLoading: boolean;
  isPlacing: boolean;
  total: number;
  totalPages: number;
  page: number;

  fetchOrders: (params?: PaginationQuery) => Promise<void>;
  fetchOrderById: (id: number) => Promise<void>;
  createOrder: (data: CreateOrderDTO) => Promise<Order>;
  cancelOrder: (id: number) => Promise<void>;
  clearCurrentOrder: () => void;
}

export const useOrderStore = create<OrderState>()((set, get) => ({
  orders: [],
  currentOrder: null,
  isLoading: false,
  isPlacing: false,
  total: 0,
  totalPages: 0,
  page: 1,

  fetchOrders: async (params) => {
    set({ isLoading: true });
    try {
      const response = await orderApi.getList(params);
      const paginatedData = response.data.data!;
      set((state) => ({
        orders:
          params?.page === 1 || !params?.page
            ? paginatedData.list
            : [...state.orders, ...paginatedData.list],
        total: paginatedData.total,
        totalPages: Math.ceil(paginatedData.total / (params?.limit || 10)),
        page: params?.page ?? 1,
        isLoading: false,
      }));
    } catch {
      set({ isLoading: false });
    }
  },

  fetchOrderById: async (id) => {
    set({ isLoading: true });
    try {
      const { data } = await orderApi.getDetail(id);
      set({ currentOrder: data.data!, isLoading: false });
    } catch {
      set({ isLoading: false });
    }
  },

  createOrder: async (orderData) => {
    set({ isPlacing: true });
    try {
      const { data } = await orderApi.create(orderData);
      const order = data.data!;
      set({ isPlacing: false });
      return order;
    } catch (error) {
      set({ isPlacing: false });
      throw error;
    }
  },

  cancelOrder: async (id) => {
    try {
      await orderApi.cancel(id);
      // 刷新订单详情
      const currentOrder = get().currentOrder;
      if (currentOrder && currentOrder.id === id) {
        await get().fetchOrderById(id);
      }
      // 刷新订单列表
      await get().fetchOrders({ page: 1 });
    } catch (error) {
      throw error;
    }
  },

  clearCurrentOrder: () => {
    set({ currentOrder: null });
  },
}));
