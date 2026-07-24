import { useState, useEffect } from 'react';
import { bannerApi } from '@/api/banner';
import type { Banner, CreateBannerDTO } from 'shared';
import { useToast } from '@/components/Toast';
import { UploadButton } from '@/components/UploadButton';

interface BannerFormData {
  title: string;
  subtitle: string;
  image: string;
  ctaText: string;
  linkType: 'none' | 'product' | 'category' | 'external';
  linkValue: string;
  sortOrder: number;
  status: number;
}

const emptyForm: BannerFormData = {
  title: '',
  subtitle: '',
  image: '',
  ctaText: '',
  linkType: 'none',
  linkValue: '',
  sortOrder: 0,
  status: 1,
};

export default function AdminBanners() {
  const { showToast } = useToast();
  const [banners, setBanners] = useState<Banner[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState<BannerFormData>(emptyForm);

  const fetchBanners = async () => {
    setIsLoading(true);
    try {
      const { data } = await bannerApi.getAll();
      setBanners(data.data ?? []);
    } catch {
      showToast('加载失败', 'error');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchBanners();
  }, []);

  const openCreate = () => {
    setForm(emptyForm);
    setEditingId(null);
    setModalOpen(true);
  };

  const openEdit = (b: Banner) => {
    setForm({
      title: b.title,
      subtitle: b.subtitle ?? '',
      image: b.image ?? '',
      ctaText: b.ctaText ?? '',
      linkType: b.linkType,
      linkValue: b.linkValue ?? '',
      sortOrder: b.sortOrder,
      status: b.status,
    });
    setEditingId(b.id);
    setModalOpen(true);
  };

  const handleSubmit = async () => {
    if (!form.title.trim()) {
      showToast('标题不能为空', 'error');
      return;
    }
    const payload: CreateBannerDTO = {
      title: form.title,
      subtitle: form.subtitle || undefined,
      image: form.image || undefined,
      ctaText: form.ctaText || undefined,
      linkType: form.linkType,
      linkValue: form.linkValue || undefined,
      sortOrder: Number(form.sortOrder),
      status: Number(form.status),
    };
    try {
      if (editingId) {
        await bannerApi.update(editingId, payload);
        showToast('更新成功', 'success');
      } else {
        await bannerApi.create(payload);
        showToast('创建成功', 'success');
      }
      setModalOpen(false);
      fetchBanners();
    } catch {
      showToast('保存失败', 'error');
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('确定删除此 Banner？')) return;
    try {
      await bannerApi.remove(id);
      showToast('删除成功', 'success');
      fetchBanners();
    } catch {
      showToast('删除失败', 'error');
    }
  };

  const inputCls =
    'w-full border border-brand-border rounded-2xl px-3 py-2 focus:ring-2 focus:ring-brand-primary/30';

  return (
    <div className="min-h-screen bg-brand-bg p-6">
      <header className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-brand-dark">Banner 管理</h1>
        <button
          onClick={openCreate}
          className="bg-brand-primary text-white px-4 py-2 rounded-2xl font-bold"
        >
          新建 Banner
        </button>
      </header>

      {isLoading ? (
        <div className="text-center py-10 text-brand-muted">加载中...</div>
      ) : banners.length === 0 ? (
        <div className="text-center py-10 text-brand-muted">暂无 Banner</div>
      ) : (
        <table className="w-full bg-brand-card rounded-2xl border border-brand-border">
          <thead className="bg-brand-btn-bg text-brand-muted text-sm">
            <tr>
              <th className="text-left p-3">标题</th>
              <th className="text-left p-3">状态</th>
              <th className="text-left p-3">排序</th>
              <th className="text-left p-3">跳转类型</th>
              <th className="text-left p-3">操作</th>
            </tr>
          </thead>
          <tbody>
            {banners.map((b) => (
              <tr key={b.id} className="border-t border-brand-border">
                <td className="p-3 font-medium">{b.title}</td>
                <td className="p-3">
                  <span
                    className={`px-2 py-0.5 rounded text-xs font-bold ${
                      b.status === 1
                        ? 'bg-brand-green/15 text-brand-green'
                        : 'bg-brand-btn-bg text-brand-muted'
                    }`}
                  >
                    {b.status === 1 ? '上架' : '下架'}
                  </span>
                </td>
                <td className="p-3">{b.sortOrder}</td>
                <td className="p-3 text-sm">{b.linkType}</td>
                <td className="p-3 flex gap-2">
                  <button
                    onClick={() => openEdit(b)}
                    className="text-brand-primary text-sm font-bold"
                  >
                    编辑
                  </button>
                  <button
                    onClick={() => handleDelete(b.id)}
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
          <div className="bg-brand-card rounded-3xl p-6 w-full max-w-md max-h-[90vh] overflow-y-auto">
            <h2 className="text-xl font-bold mb-4">{editingId ? '编辑 Banner' : '新建 Banner'}</h2>
            <div className="space-y-3">
              <input
                value={form.title}
                onChange={(e) => setForm({ ...form, title: e.target.value })}
                placeholder="标题（必填）"
                className={inputCls}
              />
              <input
                value={form.subtitle}
                onChange={(e) => setForm({ ...form, subtitle: e.target.value })}
                placeholder="副标题"
                className={inputCls}
              />
              <div>
                <label className="block text-sm font-medium text-brand-dark mb-1">背景图</label>
                <UploadButton
                  value={form.image}
                  onChange={(url) => setForm({ ...form, image: url })}
                />
              </div>
              <input
                value={form.ctaText}
                onChange={(e) => setForm({ ...form, ctaText: e.target.value })}
                placeholder="按钮文字（如 立即领取）"
                className={inputCls}
              />
              <select
                value={form.linkType}
                onChange={(e) =>
                  setForm({ ...form, linkType: e.target.value as BannerFormData['linkType'] })
                }
                className={inputCls}
              >
                <option value="none">不跳转</option>
                <option value="product">商品</option>
                <option value="category">分类</option>
                <option value="external">外部链接</option>
              </select>
              <input
                value={form.linkValue}
                onChange={(e) => setForm({ ...form, linkValue: e.target.value })}
                placeholder="跳转值（商品 id / 分类 id / URL）"
                className={inputCls}
              />
              <input
                type="number"
                value={form.sortOrder}
                onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) })}
                placeholder="排序（小的在前）"
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
