import { create } from 'zustand';
import type { CartItemWithProduct, AddToCartDTO, UpdateCartDTO } from 'shared';
import { cartApi } from '@/api/cart';

interface CartItemWithSelection extends CartItemWithProduct {
  selected: boolean;
}

interface CartState {
  items: CartItemWithSelection[];
  isLoading: boolean;
  isUpdating: boolean;
  loading: boolean; // alias for isLoading

  fetchCart: () => Promise<void>;
  addItem: (data: AddToCartDTO) => Promise<void>;
  updateQuantity: (id: number, data: UpdateCartDTO) => Promise<void>;
  removeFromCart: (id: number) => Promise<void>;
  clearCart: () => Promise<void>;
  toggleSelect: (id: number) => void;
  toggleSelectAll: () => void;

  totalCount: () => number;
  totalPrice: () => number;
  selectedItems: () => CartItemWithSelection[];
  isSelectedAll: () => boolean;
}

export const useCartStore = create<CartState>()((set, get) => ({
  items: [],
  isLoading: false,
  isUpdating: false,
  loading: false,

  fetchCart: async () => {
    set({ isLoading: true, loading: true });
    try {
      const { data } = await cartApi.getList();
      set({
        items: (data.data ?? []).map((item) => ({ ...item, selected: false })),
        isLoading: false,
        loading: false,
      });
    } catch {
      set({ isLoading: false, loading: false });
    }
  },

  addItem: async (itemData) => {
    set({ isUpdating: true });
    try {
      await cartApi.add(itemData);
      await get().fetchCart();
    } finally {
      set({ isUpdating: false });
    }
  },

  updateQuantity: async (id, updateData) => {
    set({ isUpdating: true });
    try {
      await cartApi.update(id, updateData);
      await get().fetchCart();
    } finally {
      set({ isUpdating: false });
    }
  },

  removeFromCart: async (id) => {
    set({ isUpdating: true });
    try {
      await cartApi.remove(id);
      await get().fetchCart();
    } finally {
      set({ isUpdating: false });
    }
  },

  clearCart: async () => {
    set({ isUpdating: true });
    try {
      await cartApi.clear();
      set({ items: [] });
    } finally {
      set({ isUpdating: false });
    }
  },

  toggleSelect: (id) => {
    set((state) => ({
      items: state.items.map((item) =>
        item.id === id ? { ...item, selected: !item.selected } : item,
      ),
    }));
  },

  toggleSelectAll: () => {
    const allSelected = get().isSelectedAll();
    set((state) => ({
      items: state.items.map((item) => ({ ...item, selected: !allSelected })),
    }));
  },

  totalCount: () => {
    return get().items.reduce((sum, item) => sum + item.quantity, 0);
  },

  totalPrice: () => {
    return get()
      .items.filter((item) => item.selected)
      .reduce((sum, item) => sum + item.product.price * item.quantity, 0);
  },

  selectedItems: () => {
    return get().items.filter((item) => item.selected);
  },

  isSelectedAll: () => {
    const { items } = get();
    return items.length > 0 && items.every((item) => item.selected);
  },
}));
