import type { ReactNode } from 'react';

interface BottomActionBarProps {
  children: ReactNode;
  className?: string;
}

export function BottomActionBar({ children, className = '' }: BottomActionBarProps) {
  return (
    <div
      className={`fixed bottom-0 inset-x-0 bg-white/95 backdrop-blur-[12px] border-t-[1.5px] border-brand-border z-40 safe-bottom ${className}`}
    >
      <div className="max-w-lg mx-auto px-4 py-3 flex items-center justify-between gap-3">
        {children}
      </div>
    </div>
  );
}
