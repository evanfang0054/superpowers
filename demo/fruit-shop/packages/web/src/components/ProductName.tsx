interface ProductNameProps {
  name: string;
  origin?: string;
}

export function ProductName({ name, origin }: ProductNameProps) {
  return (
    <div className="px-5 pt-2 pb-1">
      <h1 className="text-[22px] font-black text-brand-dark leading-tight m-0">{name}</h1>
      {origin && (
        <div className="flex items-center gap-1 mt-1.5">
          <svg
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.5"
            strokeLinecap="round"
            className="text-brand-green"
          >
            <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z" />
            <circle cx="12" cy="10" r="3" />
          </svg>
          <span className="text-[13px] text-brand-muted font-medium">产地直发 · {origin}</span>
        </div>
      )}
    </div>
  );
}
