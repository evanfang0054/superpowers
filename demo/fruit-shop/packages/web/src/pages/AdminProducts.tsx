import { useState, useEffect, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiClient } from '@/api/client';
import { productApi, type ProductQuery } from '@/api/product';
import { useAuthStore } from '@/store/auth.store';
import { ProductStatus } from 'shared';
import type { Product, PaginatedResponse } from 'shared';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { Toast } from '@/components/Toast';
import { UploadButton } from '@/components/UploadButton';

const STATUS_LABELS: Record<ProductStatus, string> = {
  [ProductStatus.OFF]: '已下架',
  [ProductStatus.ON]: '上架中',
};

const STATUS_COLORS: Record<ProductStatus, string> = {
  [ProductStatus.OFF]: 'text-brand-muted',
  [ProductStatus.ON]: 'text-brand-green',
};

interface ProductFormData {
  name: string;
  price: string;
  originalPrice: string;
  origin: string;
  unit: string;
  image: string;
  categoryId: string;
  stock: string;
  description: string;
  status: ProductStatus;
  sweetness: string;
  weight: string;
  color: string;
  tags: string;
  specs: string;
  isRecommended: boolean;
  featuredSortOrder: number;
}

const emptyForm: ProductFormData = {
  name: '',
  price: '',
  originalPrice: '',
  origin: '',
  unit: '斤',
  image: '',
  categoryId: '',
  stock: '100',
  description: '',
  status: ProductStatus.ON,
  sweetness: '',
  weight: '',
  color: '#FF6B35',
  tags: '',
  specs: '',
  isRecommended: false,
  featuredSortOrder: 0,
};

export default function AdminProducts() {
  const navigate = useNavigate();
  const { user } = useAuthStore();

  const [products, setProducts] = useState<Product[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [keyword, setKeyword] = useState('');

  // Modal state
  const [showModal, setShowModal] = useState(false);
  const [editingProduct, setEditingProduct] = useState<Product | null>(null);
  const [form, setForm] = useState<ProductFormData>(emptyForm);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Delete confirmation
  const [deleteTarget, setDeleteTarget] = useState<Product | null>(null);
  const [isDeleting, setIsDeleting] = useState(false);

  // Admin check
  if (user?.role !== 'admin') {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center">
        <p className="text-brand-muted">无权访问此页面</p>
        <button
          onClick={() => navigate('/')}
          className="mt-4 text-brand-primary text-sm hover:underline"
        >
          返回首页
        </button>
      </div>
    );
  }

  const fetchProducts = async (p: number, kw?: string) => {
    setIsLoading(true);
    try {
      const params: ProductQuery = { page: p, limit: 20 };
      if (kw) params.keyword = kw;

      const { data } = await productApi.getList(params);
      const paginated = data as unknown as PaginatedResponse<Product>;
      setProducts((prev) => (p === 1 ? paginated.list : [...prev, ...paginated.list]));
      setTotalPages(Math.ceil(paginated.total / 20));
    } catch {
      Toast.show('加载商品列表失败', 'error');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchProducts(1);
  }, []);

  const handleSearch = (e: FormEvent) => {
    e.preventDefault();
    setPage(1);
    fetchProducts(1, keyword);
  };

  const handleLoadMore = () => {
    const nextPage = page + 1;
    setPage(nextPage);
    fetchProducts(nextPage, keyword);
  };

  const openCreateModal = () => {
    setEditingProduct(null);
    setForm(emptyForm);
    setShowModal(true);
  };

  const openEditModal = (product: Product) => {
    setEditingProduct(product);
    setForm({
      name: product.name,
      price: product.price.toString(),
      originalPrice: product.originalPrice?.toString() || '',
      origin: product.origin,
      unit: product.unit || '',
      image: product.image || '',
      categoryId: product.categoryId?.toString() || '',
      stock: product.stock?.toString() || '0',
      description: product.description || '',
      status: product.status,
      sweetness: product.sweetness ?? '',
      weight: product.weight ?? '',
      color: product.color ?? '#FF6B35',
      tags: product.tags?.join(',') ?? '',
      specs: product.specs ? JSON.stringify(product.specs, null, 2) : '',
      isRecommended: product.isRecommended ?? false,
      featuredSortOrder: product.featuredSortOrder ?? 0,
    });
    setShowModal(true);
  };

  const handleFormSubmit = async (e: FormEvent) => {
    e.preventDefault();

    if (!form.name.trim()) {
      Toast.show('请输入商品名称', 'warning');
      return;
    }
    if (!form.price || Number(form.price) <= 0) {
      Toast.show('请输入有效价格', 'warning');
      return;
    }

    setIsSubmitting(true);
    try {
      let parsedSpecs: unknown = null;
      if (form.specs.trim()) {
        try {
          parsedSpecs = JSON.parse(form.specs);
          if (!Array.isArray(parsedSpecs)) throw new Error('not array');
        } catch {
          Toast.show('规格 JSON 格式错误', 'error');
          return;
        }
      }

      const payload = {
        name: form.name.trim(),
        price: Number(form.price),
        originalPrice: form.originalPrice ? Number(form.originalPrice) : null,
        origin: form.origin.trim(),
        unit: form.unit.trim(),
        image: form.image.trim(),
        categoryId: form.categoryId ? Number(form.categoryId) : undefined,
        stock: Number(form.stock) || 0,
        description: form.description.trim() || null,
        status: form.status,
        sweetness: form.sweetness,
        weight: form.weight,
        color: form.color,
        tags: form.tags
          .split(',')
          .map((s) => s.trim())
          .filter(Boolean),
        specs: parsedSpecs,
        isRecommended: form.isRecommended,
        featuredSortOrder: Number(form.featuredSortOrder),
      };

      if (editingProduct) {
        await apiClient.put(`/products/${editingProduct.id}`, payload);
        Toast.show('更新成功', 'success');
      } else {
        await apiClient.post('/products', payload);
        Toast.show('创建成功', 'success');
      }

      setShowModal(false);
      fetchProducts(1, keyword);
    } catch {
      Toast.show(editingProduct ? '更新失败' : '创建失败', 'error');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    setIsDeleting(true);
    try {
      await apiClient.delete(`/products/${deleteTarget.id}`);
      Toast.show('删除成功', 'success');
      setDeleteTarget(null);
      fetchProducts(1, keyword);
    } catch {
      Toast.show('删除失败', 'error');
    } finally {
      setIsDeleting(false);
    }
  };

  return (
    <div className="min-h-screen bg-brand-bg">
      {/* Header */}
      <header className="sticky top-0 z-30 bg-white/90 backdrop-blur-sm border-b border-brand-border">
        <div className="max-w-5xl mx-auto px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <button
              onClick={() => navigate('/')}
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
            <h1 className="text-lg font-semibold text-brand-dark">商品管理</h1>
          </div>
          <button
            onClick={openCreateModal}
            className="px-4 py-2 bg-brand-primary text-white text-sm font-medium rounded-2xl hover:opacity-90 transition-opacity"
          >
            + 新增商品
          </button>
        </div>
      </header>

      <main className="max-w-5xl mx-auto px-4 mt-4">
        {/* Search bar */}
        <form onSubmit={handleSearch} className="flex gap-2 mb-4">
          <input
            type="text"
            value={keyword}
            onChange={(e) => setKeyword(e.target.value)}
            placeholder="搜索商品..."
            className="flex-1 px-4 py-2 rounded-2xl border border-brand-border text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary"
          />
          <button
            type="submit"
            className="px-4 py-2 bg-brand-primary text-white text-sm rounded-2xl hover:opacity-90 transition-opacity"
          >
            搜索
          </button>
        </form>

        {/* Products table */}
        {isLoading && products.length === 0 ? (
          <div className="flex justify-center py-20">
            <LoadingSpinner size="lg" />
          </div>
        ) : products.length === 0 ? (
          <div className="text-center py-20">
            <p className="text-brand-muted text-sm">暂无商品</p>
          </div>
        ) : (
          <>
            <div className="bg-white rounded-2xl border border-brand-border overflow-hidden">
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-brand-bg border-b border-brand-border">
                      <th className="px-4 py-3 text-left font-medium text-brand-muted">商品</th>
                      <th className="px-4 py-3 text-left font-medium text-brand-muted">价格</th>
                      <th className="px-4 py-3 text-left font-medium text-brand-muted">库存</th>
                      <th className="px-4 py-3 text-left font-medium text-brand-muted">状态</th>
                      <th className="px-4 py-3 text-right font-medium text-brand-muted">操作</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-brand-bg">
                    {products.map((product) => (
                      <tr key={product.id} className="hover:bg-brand-bg transition-colors">
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-2xl overflow-hidden bg-brand-btn-bg flex-shrink-0">
                              <img
                                src={product.image || '/placeholder-fruit.png'}
                                alt={product.name}
                                className="w-full h-full object-cover"
                              />
                            </div>
                            <div>
                              <p className="font-medium text-brand-dark line-clamp-1">
                                {product.name}
                              </p>
                              {product.origin && (
                                <p className="text-xs text-brand-muted">{product.origin}</p>
                              )}
                            </div>
                          </div>
                        </td>
                        <td className="px-4 py-3">
                          <span className="text-brand-primary font-medium">
                            ¥{Number(product.price).toFixed(2)}
                          </span>
                          {product.originalPrice && (
                            <span className="text-xs text-brand-muted line-through ml-1">
                              ¥{Number(product.originalPrice).toFixed(2)}
                            </span>
                          )}
                        </td>
                        <td className="px-4 py-3 text-brand-muted">{product.stock}</td>
                        <td className="px-4 py-3">
                          <span className={`text-xs font-medium ${STATUS_COLORS[product.status]}`}>
                            {STATUS_LABELS[product.status]}
                          </span>
                        </td>
                        <td className="px-4 py-3">
                          <div className="flex items-center justify-end gap-2">
                            <button
                              onClick={() => openEditModal(product)}
                              className="px-2 py-1 text-xs text-brand-primary hover:bg-brand-primary/10 rounded transition-colors"
                            >
                              编辑
                            </button>
                            <button
                              onClick={() => setDeleteTarget(product)}
                              className="px-2 py-1 text-xs text-brand-coral hover:bg-brand-coral/10 rounded transition-colors"
                            >
                              删除
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Pagination */}
            {page < totalPages && (
              <div className="flex justify-center py-4">
                <button
                  onClick={handleLoadMore}
                  disabled={isLoading}
                  className="px-6 py-2 text-sm text-brand-primary border border-brand-primary/30 rounded-2xl hover:bg-brand-primary/5 disabled:opacity-50 transition-colors"
                >
                  {isLoading ? '加载中...' : '加载更多'}
                </button>
              </div>
            )}
          </>
        )}
      </main>

      {/* Create/Edit Modal */}
      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40">
          <div className="bg-white rounded-2xl w-full max-w-lg max-h-[85vh] overflow-y-auto border border-brand-border">
            <div className="px-5 py-4 border-b border-brand-border flex items-center justify-between">
              <h2 className="text-base font-semibold text-brand-dark">
                {editingProduct ? '编辑商品' : '新增商品'}
              </h2>
              <button
                onClick={() => setShowModal(false)}
                className="text-brand-muted hover:text-brand-muted"
              >
                <svg
                  width="20"
                  height="20"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                >
                  <path d="M18 6L6 18M6 6l12 12" />
                </svg>
              </button>
            </div>

            <form onSubmit={handleFormSubmit} className="p-5 space-y-4">
              <div>
                <label className="block text-sm font-medium text-brand-dark mb-1">商品名称</label>
                <input
                  type="text"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  placeholder="请输入商品名称"
                  className="w-full px-3 py-2.5 rounded-2xl border border-brand-border text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-brand-dark mb-1">价格</label>
                  <input
                    type="number"
                    step="0.01"
                    value={form.price}
                    onChange={(e) => setForm({ ...form, price: e.target.value })}
                    placeholder="0.00"
                    className="w-full px-3 py-2.5 rounded-2xl border border-brand-border text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-brand-dark mb-1">原价</label>
                  <input
                    type="number"
                    step="0.01"
                    value={form.originalPrice}
                    onChange={(e) => setForm({ ...form, originalPrice: e.target.value })}
                    placeholder="0.00（选填）"
                    className="w-full px-3 py-2.5 rounded-2xl border border-brand-border text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-brand-dark mb-1">产地</label>
                  <input
                    type="text"
                    value={form.origin}
                    onChange={(e) => setForm({ ...form, origin: e.target.value })}
                    placeholder="产地"
                    className="w-full px-3 py-2.5 rounded-2xl border border-brand-border text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-brand-dark mb-1">单位</label>
                  <input
                    type="text"
                    value={form.unit}
                    onChange={(e) => setForm({ ...form, unit: e.target.value })}
                    placeholder="斤"
                    className="w-full px-3 py-2.5 rounded-2xl border border-brand-border text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-brand-dark mb-1">分类ID</label>
                  <input
                    type="number"
                    value={form.categoryId}
                    onChange={(e) => setForm({ ...form, categoryId: e.target.value })}
                    placeholder="分类ID"
                    className="w-full px-3 py-2.5 rounded-2xl border border-brand-border text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-brand-dark mb-1">库存</label>
                  <input
                    type="number"
                    value={form.stock}
                    onChange={(e) => setForm({ ...form, stock: e.target.value })}
                    placeholder="库存数量"
                    className="w-full px-3 py-2.5 rounded-2xl border border-brand-border text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-brand-dark mb-1">图片</label>
                <UploadButton
                  value={form.image}
                  onChange={(url) => setForm({ ...form, image: url })}
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-brand-dark mb-1">描述</label>
                <textarea
                  value={form.description}
                  onChange={(e) => setForm({ ...form, description: e.target.value })}
                  placeholder="商品描述（选填）"
                  rows={3}
                  className="w-full px-3 py-2.5 rounded-2xl border border-brand-border text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary resize-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-brand-dark mb-1">甜度</label>
                  <input
                    type="text"
                    value={form.sweetness}
                    onChange={(e) => setForm({ ...form, sweetness: e.target.value })}
                    placeholder="如 甜、酸甜"
                    className="w-full px-3 py-2.5 rounded-2xl border border-brand-border text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-brand-dark mb-1">规格重量</label>
                  <input
                    type="text"
                    value={form.weight}
                    onChange={(e) => setForm({ ...form, weight: e.target.value })}
                    placeholder="如 500g、1kg"
                    className="w-full px-3 py-2.5 rounded-2xl border border-brand-border text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-brand-dark mb-1">色板色值</label>
                  <input
                    type="text"
                    value={form.color}
                    onChange={(e) => setForm({ ...form, color: e.target.value })}
                    placeholder="如 #FF6B35"
                    className="w-full px-3 py-2.5 rounded-2xl border border-brand-border text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-brand-dark mb-1">标签</label>
                  <input
                    type="text"
                    value={form.tags}
                    onChange={(e) => setForm({ ...form, tags: e.target.value })}
                    placeholder="逗号分隔，如 甜,新鲜,限时"
                    className="w-full px-3 py-2.5 rounded-2xl border border-brand-border text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-brand-dark mb-1">规格 JSON</label>
                <textarea
                  value={form.specs}
                  onChange={(e) => setForm({ ...form, specs: e.target.value })}
                  placeholder='如 [{"name":"规格","values":["500g/盒","1kg/袋"]}]'
                  rows={3}
                  className="w-full px-3 py-2.5 rounded-2xl border border-brand-border text-xs font-mono focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary resize-none"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-brand-dark mb-1">状态</label>
                <select
                  value={form.status}
                  onChange={(e) =>
                    setForm({ ...form, status: Number(e.target.value) as ProductStatus })
                  }
                  className="w-full px-3 py-2.5 rounded-2xl border border-brand-border text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary"
                >
                  <option value={ProductStatus.ON}>上架</option>
                  <option value={ProductStatus.OFF}>下架</option>
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="flex items-center gap-2 text-sm font-medium text-brand-dark mb-1">
                    <input
                      type="checkbox"
                      checked={form.isRecommended}
                      onChange={(e) => setForm({ ...form, isRecommended: e.target.checked })}
                      className="rounded border border-brand-border text-brand-primary focus:ring-brand-primary/30"
                    />
                    <span>设为推荐商品</span>
                  </label>
                </div>
                <div>
                  <label className="block text-sm font-medium text-brand-dark mb-1">推荐排序</label>
                  <input
                    type="number"
                    value={form.featuredSortOrder}
                    onChange={(e) =>
                      setForm({ ...form, featuredSortOrder: Number(e.target.value) })
                    }
                    placeholder="小的在前"
                    className="w-full px-3 py-2.5 rounded-2xl border border-brand-border text-sm focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary"
                  />
                </div>
              </div>

              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="flex-1 py-2.5 text-sm text-brand-muted border border-brand-border rounded-2xl hover:bg-brand-bg transition-colors"
                >
                  取消
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="flex-1 py-2.5 text-sm text-white bg-brand-primary rounded-2xl hover:opacity-90 disabled:opacity-50 transition-opacity"
                >
                  {isSubmitting ? '保存中...' : '保存'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete confirmation */}
      {deleteTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40">
          <div className="bg-white rounded-2xl w-full max-w-sm p-5 border border-brand-border">
            <h3 className="text-base font-semibold text-brand-dark mb-2">确认删除</h3>
            <p className="text-sm text-brand-muted mb-5">
              确定要删除商品「{deleteTarget.name}」吗？此操作不可恢复。
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setDeleteTarget(null)}
                className="flex-1 py-2.5 text-sm text-brand-muted border border-brand-border rounded-2xl hover:bg-brand-bg transition-colors"
              >
                取消
              </button>
              <button
                onClick={handleDelete}
                disabled={isDeleting}
                className="flex-1 py-2.5 text-sm text-white bg-brand-coral rounded-2xl hover:opacity-90 disabled:opacity-50 transition-opacity"
              >
                {isDeleting ? '删除中...' : '删除'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
