import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { couponApi, type AvailableCoupon, type MineCouponsResponse } from '@/api/coupon';
import type { UserCoupon, CouponTemplate } from 'shared';
import { CouponType } from 'shared';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { Toast } from '@/components/Toast';

type MyCouponItem = UserCoupon & { coupon: CouponTemplate | null };

const TYPE_LABEL: Record<CouponType, string> = {
  [CouponType.FULL_REDUCTION]: '满减',
  [CouponType.DISCOUNT]: '折扣',
  [CouponType.NO_THRESHOLD]: '无门槛',
};

function describeDiscount(t: CouponTemplate): string {
  if (t.type === CouponType.DISCOUNT) {
    const rate = Number(t.discountRate);
    return `${(rate * 10).toFixed(1)}折`;
  }
  return `¥${Number(t.discountAmount).toFixed(2)}`;
}

function describeThreshold(t: CouponTemplate): string {
  if (t.type === CouponType.NO_THRESHOLD) return '无门槛';
  if (t.type === CouponType.DISCOUNT) {
    return Number(t.minAmount) > 0 ? `满¥${Number(t.minAmount).toFixed(2)}可用` : '无门槛';
  }
  return `满¥${Number(t.minAmount).toFixed(2)}可用`;
}

export default function MyCoupons() {
  const navigate = useNavigate();
  const [tab, setTab] = useState<'mine' | 'available'>('mine');
  const [mine, setMine] = useState<MyCouponItem[]>([]);
  const [available, setAvailable] = useState<AvailableCoupon[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [claimingId, setClaimingId] = useState<number | null>(null);

  const fetchMine = async () => {
    setIsLoading(true);
    try {
      const { data } = await couponApi.getMine(1, 50);
      const body = data.data as MineCouponsResponse | undefined;
      setMine(body?.list ?? []);
    } catch {
      Toast.show('加载失败', 'error');
    } finally {
      setIsLoading(false);
    }
  };

  const fetchAvailable = async () => {
    setIsLoading(true);
    try {
      const { data } = await couponApi.getAvailable();
      setAvailable(data.data ?? []);
    } catch {
      Toast.show('加载失败', 'error');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (tab === 'mine') fetchMine();
    else fetchAvailable();
  }, [tab]);

  const handleClaim = async (couponId: number) => {
    setClaimingId(couponId);
    try {
      await couponApi.claim(couponId);
      Toast.show('领取成功', 'success');
      await fetchAvailable();
    } catch {
      Toast.show('领取失败', 'error');
    } finally {
      setClaimingId(null);
    }
  };

  const renderCouponCard = (t: CouponTemplate, footer?: React.ReactNode) => (
    <div
      key={footer ? `card-${t.id}` : `tpl-${t.id}`}
      className="bg-white rounded-3xl border border-brand-border overflow-hidden flex"
    >
      <div className="w-24 flex-shrink-0 bg-gradient-to-br from-brand-primary to-brand-coral text-white flex flex-col items-center justify-center py-4">
        <span className="text-[10px] opacity-90">{TYPE_LABEL[t.type]}</span>
        <span className="text-[18px] font-black leading-tight">{describeDiscount(t)}</span>
        <span className="text-[10px] opacity-90 mt-1">{describeThreshold(t)}</span>
      </div>
      <div className="flex-1 p-3 flex flex-col justify-between min-w-0">
        <div>
          <p className="text-sm font-bold text-brand-dark line-clamp-1">{t.name}</p>
          <p className="text-[11px] text-brand-muted mt-1">
            {new Date(t.startAt).toLocaleDateString()} ~ {new Date(t.endAt).toLocaleDateString()}
          </p>
          <p className="text-[11px] text-brand-muted">
            剩余 {Math.max(0, t.totalCount - t.claimedCount)}/{t.totalCount}
          </p>
        </div>
        {footer}
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-brand-bg pb-20">
      <header className="sticky top-0 z-30 bg-white/90 backdrop-blur-sm border-b border-brand-border">
        <div className="max-w-lg mx-auto px-4 py-3 flex items-center gap-3">
          <button
            onClick={() => navigate(-1)}
            className="w-9 h-9 flex items-center justify-center rounded-full bg-brand-btn-bg hover:bg-brand-border transition-colors"
          >
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
            >
              <path d="M19 12H5M12 19l-7-7 7-7" />
            </svg>
          </button>
          <h1 className="text-lg font-semibold text-brand-dark">我的优惠券</h1>
        </div>
        <div className="max-w-lg mx-auto px-4 pb-2 flex gap-2">
          <button
            onClick={() => setTab('mine')}
            className={`flex-1 py-2 rounded-full text-sm font-bold transition-colors ${
              tab === 'mine'
                ? 'bg-brand-primary text-white'
                : 'bg-white text-brand-dark border border-brand-border'
            }`}
          >
            我的优惠券
          </button>
          <button
            onClick={() => setTab('available')}
            className={`flex-1 py-2 rounded-full text-sm font-bold transition-colors ${
              tab === 'available'
                ? 'bg-brand-primary text-white'
                : 'bg-white text-brand-dark border border-brand-border'
            }`}
          >
            可领取
          </button>
        </div>
      </header>

      <main className="max-w-lg mx-auto px-4 mt-3 space-y-3">
        {isLoading ? (
          <div className="flex items-center justify-center py-10">
            <LoadingSpinner size="lg" />
          </div>
        ) : tab === 'mine' ? (
          mine.length === 0 ? (
            <div className="text-center py-10 text-brand-muted text-sm">
              还没有可用的优惠券，去「可领取」看看吧
            </div>
          ) : (
            mine.map((uc) =>
              renderCouponCard(
                uc.coupon ?? ({} as CouponTemplate),
                <div className="flex items-center justify-between mt-2">
                  <span className="text-[11px] text-brand-muted">未使用</span>
                  <span className="text-[11px] text-brand-muted">
                    领取时间 {new Date(uc.createdAt).toLocaleDateString()}
                  </span>
                </div>,
              ),
            )
          )
        ) : available.length === 0 ? (
          <div className="text-center py-10 text-brand-muted text-sm">暂无可领取的优惠券</div>
        ) : (
          available.map((t) =>
            renderCouponCard(
              t,
              <div className="flex items-center justify-end mt-2">
                <button
                  onClick={() => handleClaim(t.id)}
                  disabled={t.claimed || claimingId === t.id}
                  className={`px-4 py-1.5 rounded-full text-xs font-bold transition-colors ${
                    t.claimed
                      ? 'bg-brand-btn-bg text-brand-muted cursor-not-allowed'
                      : 'bg-brand-primary text-white hover:opacity-90'
                  }`}
                >
                  {t.claimed ? '已领取' : claimingId === t.id ? '领取中...' : '立即领取'}
                </button>
              </div>,
            ),
          )
        )}
      </main>
    </div>
  );
}
