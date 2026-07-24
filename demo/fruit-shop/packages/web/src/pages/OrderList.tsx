import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useOrderStore } from '@/store/order.store';
import { OrderStatus } from 'shared';
import type { Order } from 'shared';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { EmptyState, Button } from '@/components/ui';

const STATUS_TABS: { label: string; value: OrderStatus | null }[] = [
  { label: '全部', value: null },
  { label: '待付款', value: OrderStatus.PENDING },
  { label: '已付款', value: OrderStatus.PAID },
  { label: '已发货', value: OrderStatus.SHIPPED },
  { label: '已完成', value: OrderStatus.COMPLETED },
  { label: '已取消', value: OrderStatus.CANCELLED },
];

const STATUS_LABELS: Record<OrderStatus, string> = {
  [OrderStatus.PENDING]: '待付款',
  [OrderStatus.PAID]: '已付款',
  [OrderStatus.SHIPPED]: '已发货',
  [OrderStatus.COMPLETED]: '已完成',
  [OrderStatus.CANCELLED]: '已取消',
  [OrderStatus.REFUNDING]: '退款审核中',
  [OrderStatus.REFUNDED]: '已退款',
};

const STATUS_COLORS: Record<OrderStatus, string> = {
  [OrderStatus.PENDING]: 'text-brand-secondary',
  [OrderStatus.PAID]: 'text-brand-accent',
  [OrderStatus.SHIPPED]: 'text-brand-primary',
  [OrderStatus.COMPLETED]: 'text-brand-green',
  [OrderStatus.CANCELLED]: 'text-brand-muted',
  [OrderStatus.REFUNDING]: 'text-brand-coral',
  [OrderStatus.REFUNDED]: 'text-brand-muted',
};

export default function OrderList() {
  const navigate = useNavigate();
  const { orders, isLoading, totalPages, page, fetchOrders } = useOrderStore();

  const [activeTab, setActiveTab] = useState<OrderStatus | null>(null);

  useEffect(() => {
    fetchOrders({ page: 1, limit: 10 });
  }, [fetchOrders]);

  const handleTabChange = (status: OrderStatus | null) => {
    setActiveTab(status);
  };

  const filteredOrders = activeTab !== null ? orders.filter((o) => o.status === activeTab) : orders;

  const handleLoadMore = () => {
    if (page < totalPages) {
      fetchOrders({ page: page + 1, limit: 10 });
    }
  };

  return (
    <div className="min-h-screen bg-brand-bg pb-20">
      {/* Header */}
      <header className="sticky top-0 z-30 bg-brand-bg/90 backdrop-blur-[10px] border-b border-brand-border">
        <div className="max-w-lg mx-auto">
          <div className="px-4 py-3">
            <h1 className="text-lg font-semibold text-brand-dark text-center">我的订单</h1>
          </div>
          {/* Status tabs */}
          <div className="flex overflow-x-auto px-2 pb-2 scrollbar-hide">
            {STATUS_TABS.map((tab) => (
              <button
                key={tab.label}
                onClick={() => handleTabChange(tab.value)}
                className={`px-3 py-1.5 text-xs font-medium rounded-full whitespace-nowrap transition-colors ${
                  activeTab === tab.value
                    ? 'bg-brand-primary text-white'
                    : 'bg-white text-brand-muted border border-brand-border hover:border-brand-primary/30'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>
      </header>

      <main className="max-w-lg mx-auto px-4 mt-3">
        {/* Loading */}
        {isLoading && orders.length === 0 ? (
          <div className="flex justify-center py-20">
            <LoadingSpinner size="lg" />
          </div>
        ) : filteredOrders.length === 0 ? (
          /* Empty state */
          <EmptyState title="暂无订单" />
        ) : (
          /* Order cards */
          <div className="space-y-3">
            {filteredOrders.map((order) => (
              <OrderCard
                key={order.id}
                order={order}
                onClick={() => navigate(`/order/${order.id}`)}
              />
            ))}

            {/* Load more */}
            {page < totalPages && (
              <div className="flex justify-center py-4">
                <Button variant="ghost" size="sm" loading={isLoading} onClick={handleLoadMore}>
                  查看更多
                </Button>
              </div>
            )}
          </div>
        )}
      </main>
    </div>
  );
}

function OrderCard({ order, onClick }: { order: Order; onClick: () => void }) {
  return (
    <div
      onClick={onClick}
      className="bg-brand-card rounded-2xl border border-brand-border p-4 cursor-pointer hover:border-brand-primary/30 transition-colors"
    >
      <div className="flex items-center justify-between mb-3">
        <span className="text-xs text-brand-muted">订单号: {order.orderNo}</span>
        <span className={`text-xs font-medium ${STATUS_COLORS[order.status]}`}>
          {STATUS_LABELS[order.status]}
        </span>
      </div>

      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-brand-muted">
            {new Date(order.createdAt).toLocaleDateString('zh-CN', {
              month: 'long',
              day: 'numeric',
              hour: '2-digit',
              minute: '2-digit',
            })}
          </p>
        </div>
        <div className="text-right">
          <p className="text-lg font-bold text-brand-primary">
            ¥{Number(order.totalAmount).toFixed(2)}
          </p>
          <p className="text-xs text-brand-muted">
            {order.address?.slice(0, 15)}
            {order.address?.length > 15 ? '...' : ''}
          </p>
        </div>
      </div>

      <div className="mt-3 pt-3 border-t border-brand-border/50 flex items-center justify-between">
        <span className="text-xs text-brand-muted">
          {new Date(order.createdAt).toLocaleDateString('zh-CN')}
        </span>
        <svg
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          className="text-brand-muted/60"
        >
          <path d="M9 18l6-6-6-6" />
        </svg>
      </div>
    </div>
  );
}
