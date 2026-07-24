import { useState, useEffect, useMemo, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { useCartStore } from '@/store/cart.store';
import { useOrderStore } from '@/store/order.store';
import { addressApi } from '@/api/address';
import { couponApi, type MineCouponsResponse } from '@/api/coupon';
import type { Address, UserCoupon, CouponTemplate, CouponPreviewResponse } from 'shared';
import { CouponType } from 'shared';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { Toast } from '@/components/Toast';
import { NavBar, BottomActionBar, Button } from '@/components/ui';

type MyCouponItem = UserCoupon & { coupon: CouponTemplate | null };

const TYPE_LABEL: Record<CouponType, string> = {
  [CouponType.FULL_REDUCTION]: '满减',
  [CouponType.DISCOUNT]: '折扣',
  [CouponType.NO_THRESHOLD]: '无门槛',
};

function describeCouponLabel(t: CouponTemplate): string {
  const discount =
    t.type === CouponType.DISCOUNT
      ? `${(Number(t.discountRate) * 10).toFixed(1)}折`
      : `¥${Number(t.discountAmount).toFixed(2)}`;
  const threshold =
    t.type === CouponType.NO_THRESHOLD || Number(t.minAmount) <= 0
      ? '无门槛'
      : `满¥${Number(t.minAmount).toFixed(2)}`;
  return `${TYPE_LABEL[t.type]} · ${threshold} 减${discount}`;
}

export default function Checkout() {
  const navigate = useNavigate();
  const { selectedItems, totalPrice } = useCartStore();
  const { createOrder } = useOrderStore();

  const [address, setAddress] = useState('');
  const [phone, setPhone] = useState('');
  const [remark, setRemark] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [defaultAddr, setDefaultAddr] = useState<Address | null>(null);
  const [useAddressBook, setUseAddressBook] = useState(false);

  // 优惠券
  const [myCoupons, setMyCoupons] = useState<MyCouponItem[]>([]);
  const [couponModalOpen, setCouponModalOpen] = useState(false);
  const [selectedCoupon, setSelectedCoupon] = useState<MyCouponItem | null>(null);
  const [discountAmount, setDiscountAmount] = useState(0);
  const [couponLoading, setCouponLoading] = useState(false);

  const selected = selectedItems();
  const subtotal = totalPrice();
  const shippingFee = subtotal >= 99 ? 0 : 8;
  const totalAmount = useMemo(
    () => Math.max(0, Math.round((subtotal + shippingFee - discountAmount) * 100) / 100),
    [subtotal, shippingFee, discountAmount],
  );

  useEffect(() => {
    if (selected.length === 0) {
      Toast.show('请先选择商品', 'warning');
      navigate('/cart', { replace: true });
    }
  }, [selected.length, navigate]);

  // 拉取默认地址，自动填充
  useEffect(() => {
    addressApi
      .getList()
      .then((res) => {
        const list = res.data.data ?? [];
        const picked = list.find((a) => a.isDefault) ?? (list.length > 0 ? list[0] : null);
        if (picked) {
          setDefaultAddr(picked);
          setUseAddressBook(true);
          const full = `${picked.province}${picked.city}${picked.district}${picked.detail}`;
          setAddress(full);
          setPhone(picked.phone);
        }
      })
      .catch(() => {});
  }, []);

  // 打开选券 modal 时拉取我的可用券
  const openCouponModal = () => {
    setCouponModalOpen(true);
    if (myCoupons.length === 0) {
      couponApi
        .getMine(1, 50)
        .then((res) => {
          const body = res.data.data as MineCouponsResponse | undefined;
          setMyCoupons(body?.list ?? []);
        })
        .catch(() => {
          Toast.show('加载优惠券失败', 'error');
        });
    }
  };

  // 选中某张券 → 调 preview 拿折扣
  const handleSelectCoupon = async (item: MyCouponItem) => {
    if (!item.coupon) {
      Toast.show('券信息缺失', 'warning');
      return;
    }
    setCouponLoading(true);
    try {
      const payload = {
        couponId: item.coupon.id,
        items: selected.map((i) => ({
          productId: i.productId,
          quantity: i.quantity,
          price: Number(i.product.price),
          categoryId: i.product.categoryId,
        })),
      };
      const { data } = await couponApi.preview(payload);
      const preview = data.data as CouponPreviewResponse | undefined;
      const discount = preview?.discountAmount ?? 0;
      setSelectedCoupon(item);
      setDiscountAmount(discount);
      setCouponModalOpen(false);
      Toast.show(`已应用，本次优惠 ¥${discount.toFixed(2)}`, 'success');
    } catch {
      Toast.show('此优惠券不适用当前商品', 'error');
    } finally {
      setCouponLoading(false);
    }
  };

  const handleClearCoupon = () => {
    setSelectedCoupon(null);
    setDiscountAmount(0);
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();

    if (!address.trim()) {
      Toast.show('请输入收货地址', 'warning');
      return;
    }
    if (!phone.trim() || phone.trim().length < 11) {
      Toast.show('请输入正确的手机号', 'warning');
      return;
    }

    setIsSubmitting(true);
    try {
      const order = await createOrder({
        address: address.trim(),
        phone: phone.trim(),
        remark: remark.trim() || undefined,
        couponId: selectedCoupon?.id,
      });
      Toast.show('下单成功', 'success');
      navigate(`/order/${order.id}`, { replace: true });
    } catch {
      Toast.show('下单失败，请重试', 'error');
    } finally {
      setIsSubmitting(false);
    }
  };

  if (selected.length === 0) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-brand-bg pb-28">
      {/* Header */}
      <NavBar title="确认订单" />

      <main className="max-w-lg mx-auto px-4 mt-3">
        {/* Address form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          <section className="bg-brand-card rounded-2xl border border-brand-border p-4 space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-sm font-semibold text-brand-dark">收货信息</h2>
              <button
                type="button"
                onClick={() => navigate('/addresses')}
                className="text-[12px] text-brand-primary hover:underline"
              >
                管理地址簿
              </button>
            </div>

            {defaultAddr && (
              <div className="rounded-2xl border border-brand-border p-3 bg-brand-bg">
                <div className="flex items-center gap-2">
                  <span className="text-[13px] font-bold text-brand-dark">
                    {defaultAddr.recipientName}
                  </span>
                  <span className="text-[12px] text-brand-muted">{defaultAddr.phone}</span>
                  {defaultAddr.isDefault && (
                    <span className="px-1.5 py-0.5 rounded-md bg-brand-peach text-brand-primary text-[10px] font-bold">
                      默认
                    </span>
                  )}
                </div>
                <p className="mt-1 text-[12px] text-brand-dark">
                  {defaultAddr.province}
                  {defaultAddr.city}
                  {defaultAddr.district}
                  {defaultAddr.detail}
                </p>
                <div className="mt-2 flex items-center justify-between">
                  <label className="flex items-center gap-1.5 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={useAddressBook}
                      onChange={(e) => {
                        const next = e.target.checked;
                        setUseAddressBook(next);
                        if (next) {
                          const full = `${defaultAddr.province}${defaultAddr.city}${defaultAddr.district}${defaultAddr.detail}`;
                          setAddress(full);
                          setPhone(defaultAddr.phone);
                        }
                      }}
                      className="w-3.5 h-3.5 accent-brand-primary"
                    />
                    <span className="text-[11px] text-brand-muted">使用地址簿地址</span>
                  </label>
                  <span className="text-[11px] text-brand-muted">取消勾选可手动修改</span>
                </div>
              </div>
            )}

            <div>
              <label className="block text-sm text-brand-muted mb-1">收货地址</label>
              <textarea
                value={address}
                onChange={(e) => setAddress(e.target.value)}
                placeholder="请输入详细收货地址"
                rows={2}
                className="w-full px-3 py-2.5 rounded-2xl border border-brand-border bg-brand-bg text-brand-dark placeholder-brand-muted/70 focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary transition-colors resize-none text-sm"
              />
            </div>

            <div>
              <label className="block text-sm text-brand-muted mb-1">手机号</label>
              <input
                type="tel"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="请输入收货人手机号"
                maxLength={11}
                className="w-full px-3 py-2.5 rounded-2xl border border-brand-border bg-brand-bg text-brand-dark placeholder-brand-muted/70 focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary transition-colors text-sm"
              />
            </div>

            <div>
              <label className="block text-sm text-brand-muted mb-1">
                备注 <span className="text-brand-muted">（选填）</span>
              </label>
              <input
                type="text"
                value={remark}
                onChange={(e) => setRemark(e.target.value)}
                placeholder="对订单有什么要求？"
                maxLength={100}
                className="w-full px-3 py-2.5 rounded-2xl border border-brand-border bg-brand-bg text-brand-dark placeholder-brand-muted/70 focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary transition-colors text-sm"
              />
            </div>
          </section>

          {/* Selected items summary */}
          <section className="bg-brand-card rounded-2xl border border-brand-border p-4">
            <h2 className="text-sm font-semibold text-brand-dark mb-3">商品清单</h2>
            <div className="space-y-3">
              {selected.map((item) => (
                <div key={item.id} className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-lg overflow-hidden bg-brand-btn-bg flex-shrink-0">
                    <img
                      src={item.product.image || '/placeholder-fruit.png'}
                      alt={item.product.name}
                      className="w-full h-full object-cover"
                    />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-brand-dark line-clamp-1">{item.product.name}</p>
                    {item.specLabel && <p className="text-xs text-brand-muted">{item.specLabel}</p>}
                  </div>
                  <div className="text-right flex-shrink-0">
                    <p className="text-sm font-medium text-brand-primary">
                      ¥{Number(item.product.price).toFixed(2)}
                    </p>
                    <p className="text-xs text-brand-muted">x{item.quantity}</p>
                  </div>
                </div>
              ))}
            </div>
          </section>

          {/* Price summary */}
          <section className="bg-brand-card rounded-2xl border border-brand-border p-4">
            <div className="space-y-2 text-sm">
              <div className="flex justify-between text-brand-muted">
                <span>商品小计</span>
                <span>¥{Number(subtotal).toFixed(2)}</span>
              </div>
              <div className="flex justify-between text-brand-muted">
                <span>配送费</span>
                <span className={shippingFee === 0 ? 'text-brand-green' : ''}>
                  {shippingFee === 0 ? '免运费' : `¥${Number(shippingFee).toFixed(2)}`}
                </span>
              </div>
              {shippingFee > 0 && (
                <p className="text-xs text-brand-muted">
                  再买¥{(99 - Number(subtotal)).toFixed(2)}即可免运费
                </p>
              )}

              {/* 优惠券行 */}
              <div className="flex justify-between items-center text-brand-muted">
                <span>优惠券</span>
                {selectedCoupon ? (
                  <div className="flex items-center gap-2">
                    <span className="text-brand-coral">-¥{Number(discountAmount).toFixed(2)}</span>
                    <button
                      type="button"
                      onClick={handleClearCoupon}
                      className="text-[11px] text-brand-muted underline"
                    >
                      不使用
                    </button>
                  </div>
                ) : (
                  <button
                    type="button"
                    onClick={openCouponModal}
                    className="text-brand-primary text-[12px] font-bold"
                  >
                    选择优惠券 &gt;
                  </button>
                )}
              </div>

              <div className="border-t border-brand-border pt-2 flex justify-between items-center">
                <span className="font-medium text-brand-dark">合计</span>
                <span className="text-xl font-bold text-brand-primary">
                  ¥{Number(totalAmount).toFixed(2)}
                </span>
              </div>
            </div>
          </section>
        </form>
      </main>

      {/* Coupon picker modal */}
      {couponModalOpen && (
        <div
          className="fixed inset-0 bg-black/40 flex items-end sm:items-center justify-center z-50"
          onClick={() => setCouponModalOpen(false)}
        >
          <div
            className="bg-white rounded-t-3xl sm:rounded-3xl w-full sm:max-w-md max-h-[80vh] overflow-y-auto p-4"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-base font-bold text-brand-dark">选择优惠券</h3>
              <button
                onClick={() => setCouponModalOpen(false)}
                className="text-brand-muted text-sm"
              >
                关闭
              </button>
            </div>

            {couponLoading ? (
              <div className="py-8 flex justify-center">
                <LoadingSpinner />
              </div>
            ) : myCoupons.length === 0 ? (
              <div className="text-center py-8 text-brand-muted text-sm">暂无可用优惠券</div>
            ) : (
              <div className="space-y-2">
                {myCoupons.map((uc) => {
                  if (!uc.coupon) return null;
                  const active = selectedCoupon?.id === uc.id;
                  return (
                    <button
                      key={uc.id}
                      type="button"
                      onClick={() => handleSelectCoupon(uc)}
                      className={`w-full text-left rounded-2xl border p-3 transition-colors ${
                        active
                          ? 'border-brand-primary bg-brand-peach/30'
                          : 'border-brand-border bg-brand-bg hover:border-brand-primary/50'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-bold text-brand-dark">{uc.coupon.name}</span>
                        <span className="text-[11px] text-brand-muted">
                          {TYPE_LABEL[uc.coupon.type]}
                        </span>
                      </div>
                      <p className="text-[12px] text-brand-muted mt-1">
                        {describeCouponLabel(uc.coupon)}
                      </p>
                      <p className="text-[11px] text-brand-muted">
                        有效期至 {new Date(uc.coupon.endAt).toLocaleDateString()}
                      </p>
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Bottom submit bar */}
      <BottomActionBar>
        <div>
          <span className="text-sm text-brand-muted">应付：</span>
          <span className="text-xl font-bold text-brand-primary">
            ¥{Number(totalAmount).toFixed(2)}
          </span>
        </div>
        <Button variant="primary" loading={isSubmitting} onClick={handleSubmit}>
          {isSubmitting ? '提交中...' : '提交订单'}
        </Button>
      </BottomActionBar>
    </div>
  );
}
