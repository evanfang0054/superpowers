import type { ReactNode } from 'react';

type TagVariant = 'primary' | 'success' | 'warning' | 'accent' | 'muted';
type TagSize = 'sm' | 'md';

interface TagProps {
  children: ReactNode;
  variant?: TagVariant;
  size?: TagSize;
}

const VARIANT_CLASS: Record<TagVariant, string> = {
  primary: 'bg-brand-primary text-white',
  success: 'bg-brand-green text-white',
  warning: 'bg-brand-secondary text-brand-dark',
  accent: 'bg-brand-accent text-white',
  muted: 'bg-brand-btn-bg text-brand-muted',
};

const SIZE_CLASS: Record<TagSize, string> = {
  sm: 'px-2 py-0.5 text-[10px]',
  md: 'px-2.5 py-1 text-[11px]',
};

export function Tag({ children, variant = 'primary', size = 'md' }: TagProps) {
  return (
    <span
      className={`inline-flex items-center font-bold rounded-full ${VARIANT_CLASS[variant]} ${SIZE_CLASS[size]}`}
    >
      {children}
    </span>
  );
}
