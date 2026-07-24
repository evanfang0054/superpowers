import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useCartStore } from '@/store/cart.store';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { Toast } from '@/components/Toast';
import { NavBar, BottomActionBar, EmptyState, Button } from '@/components/ui';

export default function Cart() {
  const navigate = useNavigate();
  const {
    items,
    isLoading,
    isUpdating,
    fetchCart,
    updateQuantity,
    removeFromCart,
    toggleSelect,
    toggleSelectAll,
    totalPrice,
    selectedItems,
    isSelectedAll,
    clearCart,
  } = useCartStore();

  const [loadingItemId, setLoadingItemId] = useState<number | null>(null);
  const [clearTarget, setClearTarget] = useState(false);

  useEffect(() => {
    fetchCart();
  }, [fetchCart]);

  const handleQuantityChange = async (id: number, newQuantity: number) => {
    if (newQuantity < 1) return;
    setLoadingItemId(id);
    try {
      await updateQuantity(id, { quantity: newQuantity });
    } catch {
      Toast.show('更新数量失败', 'error');
    } finally {
      setLoadingItemId(null);
    }
  };

  const handleRemove = async (id: number) => {
    setLoadingItemId(id);
    try {
      await removeFromCart(id);
      Toast.show('已移除', 'success');
    } catch {
      Toast.show('移除失败', 'error');
    } finally {
      setLoadingItemId(null);
    }
  };

  const confirmClear = async () => {
    try {
      await clearCart();
      Toast.show('购物车已清空', 'success');
    } catch {
      Toast.show('清空失败', 'error');
    } finally {
      setClearTarget(false);
    }
  };

  const handleCheckout = () => {
    const selected = selectedItems();
    if (selected.length === 0) {
      Toast.show('请选择要结算的商品', 'warning');
      return;
    }
    navigate('/checkout');
  };

  const selectedCount = selectedItems().reduce((sum, item) => sum + item.quantity, 0);
  const total = totalPrice();

  // Loading state
  if (isLoading && items.length === 0) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  // Empty state
  if (items.length === 0) {
    return (
      <div className="min-h-screen bg-brand-bg pb-20">
        <NavBar title="购物车" showBack={false} />
        <EmptyState
          title="购物车空空如也"
          description="去挑选喜欢的水果吧"
          action={
            <Button variant="primary" size="md" onClick={() => navigate('/')}>
              去逛逛
            </Button>
          }
        />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-brand-bg pb-36">
      {/* Header */}
      <NavBar
        title="购物车"
        showBack={false}
        right={
          <div className="flex items-center gap-3">
            <span className="text-sm text-brand-muted">{items.length}件商品</span>
            {items.length > 0 && (
              <button
                onClick={() => setClearTarget(true)}
                className="text-brand-coral text-sm font-bold"
              >
                清空
              </button>
            )}
          </div>
        }
      />

      {/* Cart items */}
      <main className="max-w-lg mx-auto px-4 mt-3 space-y-3">
        {items.map((item) => (
          <div
            key={item.id}
            className="bg-brand-card rounded-2xl border border-brand-border p-4 flex gap-3"
          >
            {/* Checkbox */}
            <button
              onClick={() => toggleSelect(item.id)}
              className={`w-5 h-5 mt-4 rounded-full border-2 flex-shrink-0 flex items-center justify-center transition-colors ${
                item.selected ? 'bg-brand-primary border-brand-primary' : 'border-brand-border'
              }`}
            >
              {item.selected && (
                <svg
                  width="12"
                  height="12"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="white"
                  strokeWidth="3"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
              )}
            </button>

            {/* Product image */}
            <div
              className="w-20 h-20 rounded-xl overflow-hidden bg-brand-btn-bg flex-shrink-0 cursor-pointer"
              onClick={() => navigate(`/product/${item.productId}`)}
            >
              <img
                src={item.product.image || '/placeholder-fruit.png'}
                alt={item.product.name}
                className="w-full h-full object-cover"
              />
            </div>

            {/* Product info */}
            <div className="flex-1 min-w-0 flex flex-col justify-between">
              <div>
                <h3
                  className="text-sm font-medium text-brand-dark line-clamp-1 cursor-pointer"
                  onClick={() => navigate(`/product/${item.productId}`)}
                >
                  {item.product.name}
                </h3>
                {item.specLabel && (
                  <p className="text-xs text-brand-muted mt-0.5">{item.specLabel}</p>
                )}
              </div>

              <div className="flex items-center justify-between mt-2">
                <span className="text-brand-primary font-semibold text-sm">
                  ¥{Number(item.product.price).toFixed(2)}
                  {item.product.unit && (
                    <span className="text-xs text-brand-muted font-normal">
                      /{item.product.unit}
                    </span>
                  )}
                </span>

                {/* Quantity controls */}
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => handleQuantityChange(item.id, item.quantity - 1)}
                    disabled={item.quantity <= 1 || loadingItemId === item.id}
                    className="w-7 h-7 flex items-center justify-center rounded-full bg-brand-btn-bg text-brand-muted hover:bg-brand-bg disabled:opacity-40 transition-colors"
                  >
                    <svg
                      width="14"
                      height="14"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2"
                    >
                      <path d="M5 12h14" />
                    </svg>
                  </button>
                  <span className="text-sm font-medium w-6 text-center">
                    {loadingItemId === item.id ? '...' : item.quantity}
                  </span>
                  <button
                    onClick={() => handleQuantityChange(item.id, item.quantity + 1)}
                    disabled={loadingItemId === item.id}
                    className="w-7 h-7 flex items-center justify-center rounded-full bg-brand-primary text-white hover:opacity-90 disabled:opacity-40 transition-opacity"
                  >
                    <svg
                      width="14"
                      height="14"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2"
                    >
                      <path d="M12 5v14M5 12h14" />
                    </svg>
                  </button>
                </div>
              </div>
            </div>

            {/* Delete button */}
            <button
              onClick={() => handleRemove(item.id)}
              disabled={loadingItemId === item.id}
              className="self-start mt-1 p-1 text-brand-muted/60 hover:text-brand-coral transition-colors"
            >
              <svg
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
              >
                <path d="M18 6L6 18M6 6l12 12" />
              </svg>
            </button>
          </div>
        ))}
      </main>

      {/* Bottom checkout bar */}
      <BottomActionBar>
        <button onClick={toggleSelectAll} className="flex items-center gap-2">
          <span
            className={`w-5 h-5 rounded-full border-2 flex items-center justify-center transition-colors ${
              isSelectedAll() ? 'bg-brand-primary border-brand-primary' : 'border-brand-border'
            }`}
          >
            {isSelectedAll() && (
              <svg
                width="12"
                height="12"
                viewBox="0 0 24 24"
                fill="none"
                stroke="white"
                strokeWidth="3"
              >
                <polyline points="20 6 9 17 4 12" />
              </svg>
            )}
          </span>
          <span className="text-sm text-brand-muted">全选</span>
        </button>

        <div className="flex items-center gap-4">
          <div className="text-right">
            <span className="text-sm text-brand-muted">合计：</span>
            <span className="text-lg font-bold text-brand-primary">
              ¥{Number(total).toFixed(2)}
            </span>
          </div>
          <Button
            variant="primary"
            disabled={selectedCount === 0 || isUpdating}
            onClick={handleCheckout}
          >
            结算({selectedCount})
          </Button>
        </div>
      </BottomActionBar>

      {/* Clear confirmation modal */}
      {clearTarget && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-3xl p-6 w-full max-w-xs">
            <p className="text-center text-brand-dark font-bold mb-4">
              确定清空购物车？此操作不可撤销
            </p>
            <div className="flex gap-2">
              <Button variant="danger" fullWidth onClick={confirmClear}>
                确定清空
              </Button>
              <Button variant="ghost" fullWidth onClick={() => setClearTarget(false)}>
                取消
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
