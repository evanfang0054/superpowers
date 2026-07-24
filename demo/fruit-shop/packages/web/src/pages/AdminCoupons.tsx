import { useState, useEffect } from 'react';
import { couponApi } from '@/api/coupon';
import { productApi } from '@/api/product';
import type { CouponTemplate, CreateCouponTemplateDTO, Category } from 'shared';
import { CouponType } from 'shared';
import { useToast } from '@/components/Toast';

interface CouponFormData {
  name: string;
  type: CouponType;
  minAmount: number;
  discountAmount: number;
  discountRate: number | '';
  categoryId: number | '';
  totalCount: number;
  startAt: string;
  endAt: string;
  status: number;
}

const emptyForm: CouponFormData = {
  name: '',
  type: CouponType.FULL_REDUCTION,
  minAmount: 0,
  discountAmount: 0,
  discountRate: '',
  categoryId: '',
  totalCount: 100,
  startAt: '',
  endAt: '',
  status: 1,
};

const TYPE_LABEL: Record<CouponType, string> = {
  [CouponType.FULL_REDUCTION]: '满减',
  [CouponType.DISCOUNT]: '折扣',
  [CouponType.NO_THRESHOLD]: '无门槛',
};

// 将 ISO 时间字符串截到 datetime-local 需要的 "YYYY-MM-DDTHH:mm" 格式
function toLocalInput(iso: string | Date | undefined): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export default function AdminCoupons() {
  const { showToast } = useToast();
  const [templates, setTemplates] = useState<CouponTemplate[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState<CouponFormData>(emptyForm);

  const fetchAll = async () => {
    setIsLoading(true);
    try {
      const [tplRes, catRes] = await Promise.all([
        couponApi.findAllTemplates(),
        productApi.getCategories(),
      ]);
      setTemplates(tplRes.data.data ?? []);
      setCategories(catRes.data.data ?? []);
    } catch {
      showToast('加载失败', 'error');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchAll();
  }, []);

  const openCreate = () => {
    setForm(emptyForm);
    setEditingId(null);
    setModalOpen(true);
  };

  const openEdit = (t: CouponTemplate) => {
    setForm({
      name: t.name,
      type: t.type,
      minAmount: Number(t.minAmount) || 0,
      discountAmount: Number(t.discountAmount) || 0,
      discountRate: t.discountRate == null ? '' : Number(t.discountRate),
      categoryId: t.categoryId == null ? '' : t.categoryId,
      totalCount: t.totalCount ?? 0,
      startAt: toLocalInput(t.startAt),
      endAt: toLocalInput(t.endAt),
      status: t.status,
    });
    setEditingId(t.id);
    setModalOpen(true);
  };

  const handleSubmit = async () => {
    if (!form.name.trim()) {
      showToast('名称不能为空', 'error');
      return;
    }
    if (!form.startAt || !form.endAt) {
      showToast('请填写生效时间', 'error');
      return;
    }
    const payload: CreateCouponTemplateDTO = {
      name: form.name.trim(),
      type: form.type,
      minAmount: form.type === CouponType.NO_THRESHOLD ? 0 : Number(form.minAmount) || 0,
      discountAmount: form.type === CouponType.DISCOUNT ? 0 : Number(form.discountAmount) || 0,
      discountRate:
        form.type === CouponType.DISCOUNT && form.discountRate !== ''
          ? Number(form.discountRate)
          : undefined,
      categoryId: form.categoryId === '' ? undefined : Number(form.categoryId),
      totalCount: Number(form.totalCount) || 0,
      startAt: new Date(form.startAt).toISOString(),
      endAt: new Date(form.endAt).toISOString(),
      status: Number(form.status),
    };
    try {
      if (editingId) {
        await couponApi.updateTemplate(editingId, payload);
        showToast('更新成功', 'success');
      } else {
        await couponApi.createTemplate(payload);
        showToast('创建成功', 'success');
      }
      setModalOpen(false);
      fetchAll();
    } catch {
      showToast('保存失败', 'error');
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('确定删除此优惠券模板？')) return;
    try {
      await couponApi.removeTemplate(id);
      showToast('删除成功', 'success');
      fetchAll();
    } catch {
      showToast('删除失败', 'error');
    }
  };

  const inputCls =
    'w-full border border-brand-border rounded-2xl px-3 py-2 focus:ring-2 focus:ring-brand-primary/30';

  return (
    <div className="min-h-screen bg-brand-bg p-6">
      <header className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-brand-dark">优惠券管理</h1>
        <button
          onClick={openCreate}
          className="bg-brand-primary text-white px-4 py-2 rounded-2xl font-bold"
        >
          新建模板
        </button>
      </header>

      {isLoading ? (
        <div className="text-center py-10 text-brand-muted">加载中...</div>
      ) : templates.length === 0 ? (
        <div className="text-center py-10 text-brand-muted">暂无优惠券模板</div>
      ) : (
        <table className="w-full bg-white rounded-2xl border border-brand-border">
          <thead className="bg-brand-btn-bg text-brand-muted text-sm">
            <tr>
              <th className="text-left p-3">名称</th>
              <th className="text-left p-3">类型</th>
              <th className="text-left p-3">门槛/折扣</th>
              <th className="text-left p-3">已领/总量</th>
              <th className="text-left p-3">有效期</th>
              <th className="text-left p-3">状态</th>
              <th className="text-left p-3">操作</th>
            </tr>
          </thead>
          <tbody>
            {templates.map((t) => (
              <tr key={t.id} className="border-t border-brand-border">
                <td className="p-3 font-medium">{t.name}</td>
                <td className="p-3">{TYPE_LABEL[t.type]}</td>
                <td className="p-3 text-sm">
                  {t.type === CouponType.DISCOUNT
                    ? `${(Number(t.discountRate) * 10).toFixed(1)}折`
                    : t.type === CouponType.NO_THRESHOLD
                      ? `减¥${Number(t.discountAmount).toFixed(2)}`
                      : `满¥${Number(t.minAmount).toFixed(2)} 减¥${Number(t.discountAmount).toFixed(2)}`}
                </td>
                <td className="p-3 text-sm">
                  {t.claimedCount}/{t.totalCount}
                </td>
                <td className="p-3 text-xs text-brand-muted">
                  {new Date(t.startAt).toLocaleDateString()} ~{' '}
                  {new Date(t.endAt).toLocaleDateString()}
                </td>
                <td className="p-3">
                  <span
                    className={`px-2 py-0.5 rounded text-xs font-bold ${
                      t.status === 1
                        ? 'bg-brand-green/15 text-brand-green'
                        : 'bg-brand-btn-bg text-brand-muted'
                    }`}
                  >
                    {t.status === 1 ? '上架' : '下架'}
                  </span>
                </td>
                <td className="p-3 flex gap-2">
                  <button
                    onClick={() => openEdit(t)}
                    className="text-brand-primary text-sm font-bold"
                  >
                    编辑
                  </button>
                  <button
                    onClick={() => handleDelete(t.id)}
                    className="text-red-500 text-sm font-bold"
                  >
                    删除
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {modalOpen && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-3xl p-6 w-full max-w-md max-h-[90vh] overflow-y-auto">
            <h2 className="text-xl font-bold mb-4">{editingId ? '编辑模板' : '新建模板'}</h2>
            <div className="space-y-3">
              <input
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="优惠券名称"
                className={inputCls}
              />
              <select
                value={form.type}
                onChange={(e) => setForm({ ...form, type: Number(e.target.value) as CouponType })}
                className={inputCls}
              >
                <option value={CouponType.FULL_REDUCTION}>满减（满 X 减 Y）</option>
                <option value={CouponType.DISCOUNT}>折扣（如 0.85 = 8.5折）</option>
                <option value={CouponType.NO_THRESHOLD}>无门槛（直减）</option>
              </select>

              {form.type !== CouponType.NO_THRESHOLD && (
                <input
                  type="number"
                  step="0.01"
                  value={form.minAmount}
                  onChange={(e) => setForm({ ...form, minAmount: Number(e.target.value) })}
                  placeholder="最低消费门槛 minAmount"
                  className={inputCls}
                />
              )}

              {form.type === CouponType.DISCOUNT ? (
                <input
                  type="number"
                  step="0.01"
                  min="0"
                  max="1"
                  value={form.discountRate}
                  onChange={(e) =>
                    setForm({
                      ...form,
                      discountRate: e.target.value === '' ? '' : Number(e.target.value),
                    })
                  }
                  placeholder="折扣率 0~1（如 0.85）"
                  className={inputCls}
                />
              ) : (
                <input
                  type="number"
                  step="0.01"
                  value={form.discountAmount}
                  onChange={(e) => setForm({ ...form, discountAmount: Number(e.target.value) })}
                  placeholder="减免金额 discountAmount"
                  className={inputCls}
                />
              )}

              <select
                value={form.categoryId}
                onChange={(e) =>
                  setForm({
                    ...form,
                    categoryId: e.target.value === '' ? '' : Number(e.target.value),
                  })
                }
                className={inputCls}
              >
                <option value="">全品类适用</option>
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>
                    仅限：{c.name}
                  </option>
                ))}
              </select>

              <input
                type="number"
                value={form.totalCount}
                onChange={(e) => setForm({ ...form, totalCount: Number(e.target.value) })}
                placeholder="发放总量 totalCount"
                className={inputCls}
              />

              <label className="block text-xs text-brand-muted">生效时间</label>
              <input
                type="datetime-local"
                value={form.startAt}
                onChange={(e) => setForm({ ...form, startAt: e.target.value })}
                className={inputCls}
              />
              <label className="block text-xs text-brand-muted">失效时间</label>
              <input
                type="datetime-local"
                value={form.endAt}
                onChange={(e) => setForm({ ...form, endAt: e.target.value })}
                className={inputCls}
              />

              <select
                value={form.status}
                onChange={(e) => setForm({ ...form, status: Number(e.target.value) })}
                className={inputCls}
              >
                <option value={1}>上架</option>
                <option value={0}>下架</option>
              </select>
            </div>
            <div className="flex gap-2 mt-6">
              <button
                onClick={handleSubmit}
                className="flex-1 py-2.5 rounded-2xl bg-brand-primary text-white font-bold"
              >
                保存
              </button>
              <button
                onClick={() => setModalOpen(false)}
                className="flex-1 py-2.5 rounded-2xl border border-brand-border font-bold"
              >
                取消
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
