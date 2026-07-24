import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { productApi } from '@/api/product';
import type { Product } from 'shared';
import { ProductHero } from '@/components/ProductHero';
import { ProductName } from '@/components/ProductName';
import { PriceSection } from '@/components/PriceSection';
import { SpecSelector } from '@/components/SpecSelector';
import { QualityInfo } from '@/components/QualityInfo';
import { Description } from '@/components/Description';
import { RecommendFruits } from '@/components/RecommendFruits';
import { ReviewSection } from '@/components/ReviewSection';
import { FavoriteToggle } from '@/components/FavoriteToggle';
import { DecorDots } from '@/components/DecorDots';
import { BuyBar } from '@/components/BuyBar';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { useToast } from '@/components/Toast';
import { useCartStore } from '@/store/cart.store';

export default function ProductDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { showToast } = useToast();
  const cartCount = useCartStore((s) => s.totalCount());

  const [product, setProduct] = useState<Product | null>(null);
  const [recommendations, setRecommendations] = useState<Product[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedSpecs, setSelectedSpecs] = useState<Record<string, string>>({});

  useEffect(() => {
    if (!id) return;

    const fetchProduct = async () => {
      setIsLoading(true);
      try {
        const { data } = await productApi.getDetail(Number(id));
        setProduct(data.data!);
      } catch {
        showToast('商品不存在或已下架', 'error');
        navigate('/', { replace: true });
      } finally {
        setIsLoading(false);
      }
    };

    fetchProduct();
  }, [id, navigate, showToast]);

  useEffect(() => {
    productApi
      .getRecommendations(5)
      .then((res) => {
        const items = res.data.data || [];
        setRecommendations(items.filter((p: Product) => p.id !== Number(id)).slice(0, 4));
      })
      .catch(() => {});
  }, [id]);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-brand-bg">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  if (!product) return null;

  const specs = product.specs ?? [];

  const handleRecommendClick = (productId: number) => {
    navigate(`/product/${productId}`);
    window.scrollTo(0, 0);
  };

  return (
    <div className="relative bg-brand-bg min-h-screen animate-fade-in">
      <DecorDots />

      {/* 导航栏 */}
      <div className="flex items-center justify-between px-4 py-3 bg-brand-bg/90 backdrop-blur-[10px] sticky top-0 z-50">
        <div onClick={() => navigate(-1)} className="cursor-pointer flex items-center gap-1">
          <svg
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.5"
            strokeLinecap="round"
            className="text-brand-dark"
          >
            <path d="M15 18l-6-6 6-6" />
          </svg>
        </div>
        <span className="font-bold text-[17px] text-brand-dark">{product.name}</span>
        <div className="flex gap-3">
          <FavoriteToggle productId={product.id} />
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
            <path d="M4 12v8a2 2 0 002 2h12a2 2 0 002-2v-8" />
            <polyline points="16,6 12,2 8,6" />
            <line x1="12" y1="2" x2="12" y2="15" />
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

      {/* 商品大图 */}
      <ProductHero
        image={product.image || '/placeholder-fruit.png'}
        name={product.name}
        color={product.color || '#FF6B35'}
      />

      {/* 商品名称 + 产地 */}
      <ProductName name={product.name} origin={product.origin} />

      {/* 价格 + tag */}
      <PriceSection
        price={product.price}
        originalPrice={product.originalPrice ?? undefined}
        unit={product.unit ?? undefined}
        tags={product.tags ?? undefined}
      />

      {/* 规格选择 */}
      {specs.length > 0 && (
        <div className="px-5 pb-4">
          <div className="text-sm font-bold text-brand-dark mb-2.5">选择规格</div>
          <SpecSelector specs={specs} onChange={setSelectedSpecs} />
        </div>
      )}

      {/* 品质信息 2×2 */}
      <QualityInfo sweetness={product.sweetness} weight={product.weight} />

      {/* 水果故事 */}
      <Description text={product.description ?? undefined} />

      {/* 用户评价 */}
      <ReviewSection productId={product.id} />

      {/* 推荐水果 */}
      <RecommendFruits items={recommendations} onClick={handleRecommendClick} />

      {/* 底部占位 */}
      <div className="h-[70px]" />

      {/* 底部购买栏 */}
      <BuyBar product={product} selectedSpecs={selectedSpecs} />
    </div>
  );
}
