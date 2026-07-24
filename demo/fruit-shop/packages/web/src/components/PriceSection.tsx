interface PriceSectionProps {
  price: number;
  originalPrice?: number;
  unit?: string;
  tags?: string[];
}

export function PriceSection({ price, originalPrice, unit, tags }: PriceSectionProps) {
  return (
    <div className="px-5 pb-4">
      <div className="flex items-baseline gap-2">
        <span className="text-sm font-bold text-brand-primary">¥</span>
        <span className="text-[36px] font-black text-brand-primary font-display leading-none">
          {price}
        </span>
        {unit && <span className="text-[13px] text-brand-muted">/ {unit}</span>}
        {originalPrice && originalPrice > price && (
          <span className="text-[13px] text-brand-muted line-through ml-1">¥{originalPrice}</span>
        )}
      </div>
      {tags && tags.length > 0 && (
        <div className="flex gap-2 mt-2.5 flex-wrap">
          {tags.map((tag, i) => (
            <span
              key={i}
              className="py-1 px-3 rounded-full text-[11px] font-semibold"
              style={{
                background:
                  i === 0
                    ? 'color-mix(in srgb, var(--color-brand-primary) 9%, transparent)'
                    : 'color-mix(in srgb, var(--color-brand-secondary) 19%, transparent)',
                color: i === 0 ? 'var(--color-brand-primary)' : 'var(--color-brand-dark)',
                border:
                  i === 0
                    ? '1.5px solid color-mix(in srgb, var(--color-brand-primary) 27%, transparent)'
                    : '1.5px solid color-mix(in srgb, var(--color-brand-secondary) 33%, transparent)',
              }}
            >
              {tag}
            </span>
          ))}
        </div>
      )}
    </div>
  );
}
