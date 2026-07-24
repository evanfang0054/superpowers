import type { ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { IconButton } from './IconButton';

interface NavBarProps {
  title?: ReactNode;
  left?: ReactNode;
  right?: ReactNode;
  showBack?: boolean;
  sticky?: boolean;
}

export function NavBar({ title, left, right, showBack = true, sticky = true }: NavBarProps) {
  const navigate = useNavigate();
  const positionClass = sticky ? 'sticky top-0 z-50' : '';

  const defaultLeft = showBack ? (
    <IconButton
      variant="ghost"
      shape="circle"
      size="md"
      aria-label="返回"
      onClick={() => navigate(-1)}
    >
      <svg
        width="18"
        height="18"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="M19 12H5M12 19l-7-7 7-7" />
      </svg>
    </IconButton>
  ) : null;

  return (
    <header
      className={`bg-brand-bg/90 backdrop-blur-[10px] border-b border-brand-border h-12 flex items-center px-4 ${positionClass}`}
    >
      <div className="flex items-center gap-2 min-w-0">{left ?? defaultLeft}</div>
      {title && (
        <div className="flex-1 text-center font-bold text-[17px] text-brand-dark truncate px-2">
          {title}
        </div>
      )}
      {!title && <div className="flex-1" />}
      <div className="flex items-center gap-3 min-w-0">{right}</div>
    </header>
  );
}
