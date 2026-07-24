import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { productApi, type ProductQuery } from '@/api/product';
import type { Product, Category } from 'shared';
import { ProductCard } from '@/components/ProductCard';
import { CategoryTabs } from '@/components/CategoryTabs';
import { SearchBar } from '@/components/SearchBar';
import { PromoBanner } from '@/components/PromoBanner';
import { DecorDots } from '@/components/DecorDots';
import { TabBar } from '@/components/TabBar';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { useCartStore } from '@/store/cart.store';

export default function Home() {
  const navigate = useNavigate();
  const cartCount = useCartStore((s) => s.totalCount());

  const [products, setProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [keyword, setKeyword] = useState('');
  const [activeCategory, setActiveCategory] = useState<number | undefined>();
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);

  const fetchProducts = useCallback(async (p: number, kw?: string, catId?: number) => {
    setIsLoading(true);
    try {
      const params: ProductQuery = { page: p, limit: 12 };
      if (kw) params.keyword = kw;
      if (catId) params.categoryId = catId;

      const response = await productApi.getList(params);
      const items = response.data.data?.list || [];

      setProducts((prev) => (p === 1 ? items : [...prev, ...items]));
      setHasMore(items.length >= 12);
    } catch {
      // 静默
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    productApi
      .getCategories()
      .then((res) => {
        setCategories(res.data.data || []);
      })
      .catch(() => {});
  }, []);

  useEffect(() => {
    setPage(1);
    fetchProducts(1, keyword, activeCategory);
  }, [keyword, activeCategory, fetchProducts]);

  const handleSearch = (kw: string) => {
    setKeyword(kw);
  };

  const handleCategoryChange = (catId?: number) => {
    setActiveCategory(catId);
  };

  const handleLoadMore = () => {
    const nextPage = page + 1;
    setPage(nextPage);
    fetchProducts(nextPage, keyword, activeCategory);
  };

  return (
    <div className="relative bg-brand-bg min-h-screen pb-20">
      <DecorDots />

      {/* 顶部导航 */}
      <div className="flex items-center justify-between px-4 py-3 bg-brand-bg/90 backdrop-blur-[10px] sticky top-0 z-50">
        <div className="flex items-center gap-2">
          <span className="text-2xl">🍊</span>
          <span className="font-black text-xl text-brand-dark font-display">鲜果集</span>
        </div>
        <div className="flex items-center gap-3">
          <svg
            width="22"
            height="22"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            className="text-brand-dark"
          >
            <circle cx="11" cy="11" r="8" />
            <line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
          <div className="relative cursor-pointer" onClick={() => navigate('/cart')}>
            <svg
              width="22"
              height="22"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              className="text-brand-dark"
            >
              <circle cx="9" cy="21" r="1" />
              <circle cx="20" cy="21" r="1" />
              <path d="M1 1h4l2.68 13.39a2 2 0 002 1.61h9.72a2 2 0 002-1.61L23 6H6" />
            </svg>
            {cartCount > 0 && (
              <div className="absolute -top-1 -right-1.5 w-4 h-4 rounded-full bg-brand-accent text-white text-[10px] font-bold flex items-center justify-center">
                {cartCount > 99 ? '99+' : cartCount}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* 搜索栏 */}
      <SearchBar onSearch={handleSearch} />

      {/* 分类标签 */}
      <div className="px-4 py-2">
        <CategoryTabs
          categories={categories}
          activeId={activeCategory}
          onChange={handleCategoryChange}
        />
      </div>

      {/* 促销 Banner */}
      <PromoBanner />

      {/* 商品列表 */}
      <div className="px-4 pb-6">
        <div className="flex items-center justify-between mb-3">
          <h2 className="font-display text-lg font-semibold text-brand-dark">
            {activeCategory
              ? categories.find((c) => c.id === activeCategory)?.name || '精选好果'
              : '精选好果'}
          </h2>
        </div>

        {isLoading && page === 1 ? (
          <div className="flex justify-center py-20">
            <LoadingSpinner size="lg" />
          </div>
        ) : products.length === 0 ? (
          <div className="text-center py-20">
            <p className="text-brand-muted text-sm">
              {keyword ? `未找到"${keyword}"相关水果` : '暂无商品'}
            </p>
          </div>
        ) : (
          <>
            <div className="grid grid-cols-2 gap-3">
              {products.map((product, i) => (
                <div
                  key={product.id}
                  className="animate-slide-up"
                  style={{ animationDelay: `${i * 60}ms`, animationFillMode: 'both' }}
                >
                  <ProductCard product={product} />
                </div>
              ))}
            </div>

            {hasMore && (
              <div className="flex justify-center mt-6">
                <button
                  onClick={handleLoadMore}
                  disabled={isLoading}
                  className="px-6 py-2 text-sm text-brand-primary border border-brand-primary/30 rounded-full hover:bg-brand-primary/5 disabled:opacity-50 transition-colors"
                >
                  {isLoading ? '加载中...' : '查看更多'}
                </button>
              </div>
            )}
          </>
        )}
      </div>

      <TabBar />
    </div>
  );
}
