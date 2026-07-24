import { useState, useEffect } from 'react';
import { categoryApi } from '@/api/category';
import type { Category } from 'shared';
import { useToast } from '@/components/Toast';

interface CategoryFormData {
  name: string;
  icon: string;
  sortOrder: number;
}

const emptyForm: CategoryFormData = {
  name: '',
  icon: '',
  sortOrder: 0,
};

export default function AdminCategories() {
  const { showToast } = useToast();
  const [categories, setCategories] = useState<Category[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState<CategoryFormData>(emptyForm);

  const fetchCategories = async () => {
    setIsLoading(true);
    try {
      const { data } = await categoryApi.getAll();
      setCategories(data.data ?? []);
    } catch {
      showToast('加载失败', 'error');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchCategories();
  }, []);

  const openCreate = () => {
    setForm(emptyForm);
    setEditingId(null);
    setModalOpen(true);
  };

  const openEdit = (c: Category) => {
    setForm({
      name: c.name,
      icon: c.icon ?? '',
      sortOrder: c.sortOrder,
    });
    setEditingId(c.id);
    setModalOpen(true);
  };

  const handleSubmit = async () => {
    if (!form.name.trim()) {
      showToast('名称不能为空', 'error');
      return;
    }
    const payload = {
      name: form.name.trim(),
      icon: form.icon || undefined,
      sortOrder: Number(form.sortOrder),
    };
    try {
      if (editingId) {
        await categoryApi.update(editingId, payload);
        showToast('更新成功', 'success');
      } else {
        await categoryApi.create(payload);
        showToast('创建成功', 'success');
      }
      setModalOpen(false);
      fetchCategories();
    } catch {
      showToast('保存失败', 'error');
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('确定删除此分类？关联在售商品时不可删除。')) return;
    try {
      await categoryApi.remove(id);
      showToast('删除成功', 'success');
      fetchCategories();
    } catch {
      showToast('删除失败', 'error');
    }
  };

  const inputCls =
    'w-full border border-brand-border rounded-2xl px-3 py-2 focus:ring-2 focus:ring-brand-primary/30';

  return (
    <div className="min-h-screen bg-brand-bg p-6">
      <header className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-brand-dark">分类管理</h1>
        <button
          onClick={openCreate}
          className="bg-brand-primary text-white px-4 py-2 rounded-2xl font-bold"
        >
          新建分类
        </button>
      </header>

      {isLoading ? (
        <div className="text-center py-10 text-brand-muted">加载中...</div>
      ) : categories.length === 0 ? (
        <div className="text-center py-10 text-brand-muted">暂无分类</div>
      ) : (
        <table className="w-full bg-white rounded-2xl border border-brand-border">
          <thead className="bg-brand-btn-bg text-brand-muted text-sm">
            <tr>
              <th className="text-left p-3">ID</th>
              <th className="text-left p-3">名称</th>
              <th className="text-left p-3">图标</th>
              <th className="text-left p-3">排序</th>
              <th className="text-left p-3">操作</th>
            </tr>
          </thead>
          <tbody>
            {categories.map((c) => (
              <tr key={c.id} className="border-t border-brand-border">
                <td className="p-3 text-brand-muted">{c.id}</td>
                <td className="p-3 font-medium">{c.name}</td>
                <td className="p-3">{c.icon ?? '-'}</td>
                <td className="p-3">{c.sortOrder}</td>
                <td className="p-3 flex gap-2">
                  <button
                    onClick={() => openEdit(c)}
                    className="text-brand-primary text-sm font-bold"
                  >
                    编辑
                  </button>
                  <button
                    onClick={() => handleDelete(c.id)}
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
          <div className="bg-white rounded-3xl p-6 w-full max-w-md">
            <h2 className="text-xl font-bold mb-4">{editingId ? '编辑分类' : '新建分类'}</h2>
            <div className="space-y-3">
              <input
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="名称（必填）"
                className={inputCls}
              />
              <input
                value={form.icon}
                onChange={(e) => setForm({ ...form, icon: e.target.value })}
                placeholder="图标 URL 或 emoji（可选）"
                className={inputCls}
              />
              <input
                type="number"
                value={form.sortOrder}
                onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) })}
                placeholder="排序（小的在前）"
                className={inputCls}
              />
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
