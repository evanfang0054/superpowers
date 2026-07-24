import { useNavigate } from 'react-router-dom';
import type { Product } from 'shared';

interface ProductCardProps {
  product: Product;
}

export function ProductCard({ product }: ProductCardProps) {
  const navigate = useNavigate();

  const tags = product.tags || [];

  return (
    <div
      onClick={() => navigate(`/product/${product.id}`)}
      className="bg-brand-card rounded-3xl border border-brand-border overflow-hidden cursor-pointer transition-transform duration-200 hover:scale-[1.02] active:scale-[0.98]"
    >
      <div className="relative">
        <img
          src={product.image || '/placeholder-fruit.png'}
          alt={product.name}
          className="w-full h-[160px] object-cover"
        />
        {tags[0] && (
          <div
            className="absolute top-2.5 left-2.5 px-2.5 py-1 rounded-full text-[10px] font-bold text-white"
            style={{ background: (product.color || '#FF6B35') + 'CC' }}
          >
            {tags[0]}
          </div>
        )}
      </div>
      <div className="p-3">
        <div className="flex items-center justify-between">
          <h3 className="text-[15px] font-bold text-brand-dark">{product.name}</h3>
          {product.origin && <span className="text-[11px] text-brand-muted">{product.origin}</span>}
        </div>
        <div className="flex items-baseline justify-between mt-2">
          <div className="flex items-baseline gap-1">
            <span className="text-xs text-brand-primary font-bold">¥</span>
            <span className="text-xl font-extrabold text-brand-primary font-display leading-none">
              {product.price}
            </span>
            {product.unit && (
              <span className="text-[11px] text-brand-muted ml-0.5">/{product.unit}</span>
            )}
          </div>
          {product.originalPrice && product.originalPrice > product.price && (
            <span className="text-[11px] text-brand-muted line-through">
              ¥{product.originalPrice}
            </span>
          )}
        </div>
      </div>
    </div>
  );
}
