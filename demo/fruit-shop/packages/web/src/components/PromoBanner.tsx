import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import type { Banner } from 'shared';
import { bannerApi } from '@/api/banner';

export function PromoBanner() {
  const navigate = useNavigate();
  const [banner, setBanner] = useState<Banner | null>(null);

  useEffect(() => {
    bannerApi
      .getActive()
      .then((res) => {
        const list = res.data.data ?? [];
        setBanner(list.length > 0 ? list[0] : null);
      })
      .catch(() => setBanner(null));
  }, []);

  if (!banner) return null;

  const handleCta = () => {
    if (!banner.ctaText) return;
    switch (banner.linkType) {
      case 'product':
        navigate(`/product/${banner.linkValue}`);
        break;
      case 'category':
        navigate(`/?categoryId=${banner.linkValue}`);
        break;
      case 'external':
        if (banner.linkValue) {
          window.open(banner.linkValue, '_blank', 'noopener');
        }
        break;
      case 'none':
      default:
        break;
    }
  };

  return (
    <div
      className="relative rounded-3xl overflow-hidden mx-4 my-4"
      style={{ background: 'var(--gradient-promo)' }}
    >
      {banner.image && (
        <img
          src={banner.image}
          alt={banner.title}
          className="absolute inset-0 w-full h-full object-cover opacity-20"
        />
      )}
      <div className="relative p-5 flex items-center justify-between">
        <div className="flex-1">
          <div className="text-white font-bold text-lg">{banner.title}</div>
          {banner.subtitle && <div className="text-white/90 text-sm mt-1">{banner.subtitle}</div>}
        </div>
        {banner.ctaText && (
          <button
            onClick={handleCta}
            className="bg-white text-brand-primary font-bold text-sm px-4 py-2 rounded-full whitespace-nowrap"
          >
            {banner.ctaText}
          </button>
        )}
      </div>
    </div>
  );
}
