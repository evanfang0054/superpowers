import { createContext, useContext, useState, useCallback } from 'react';

type ToastType = 'success' | 'error' | 'warning' | 'info';

interface ToastItem {
  id: number;
  message: string;
  type: ToastType;
}

interface ToastContextValue {
  showToast: (message: string, type?: ToastType) => void;
}

const ToastContext = createContext<ToastContextValue | null>(null);

export function useToast() {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error('useToast must be used within ToastProvider');
  return ctx;
}

let toastId = 0;

// 用于 Toast.show() 静态方法的外部 showToast 引用
let externalShowToast: ((message: string, type?: ToastType) => void) | null = null;

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([]);

  const showToast = useCallback((message: string, type: ToastType = 'info') => {
    const id = ++toastId;
    setToasts((prev) => [...prev, { id, message, type }]);
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 3000);
  }, []);

  // 注册到外部引用
  externalShowToast = showToast;

  const removeToast = (id: number) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  };

  const typeStyles: Record<ToastType, string> = {
    success: 'bg-brand-green text-white',
    error: 'bg-brand-coral text-white',
    warning: 'bg-brand-secondary text-brand-dark',
    info: 'bg-brand-accent text-white',
  };

  return (
    <ToastContext.Provider value={{ showToast }}>
      {children}
      <div className="fixed top-4 right-4 z-[9999] flex flex-col gap-2">
        {toasts.map((toast) => (
          <div
            key={toast.id}
            className={`animate-slide-up rounded-2xl px-4 py-3 shadow-lg text-sm font-medium min-w-[240px] max-w-[360px] flex items-center justify-between ${typeStyles[toast.type]}`}
          >
            <span>{toast.message}</span>
            <button
              onClick={() => removeToast(toast.id)}
              className="ml-3 opacity-70 hover:opacity-100"
            >
              &times;
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

// 静态方法：允许在非 React 组件中调用
(ToastProvider as unknown as { show: (message: string, type?: ToastType) => void }).show =
  function (message: string, type: ToastType = 'info') {
    if (externalShowToast) {
      externalShowToast(message, type);
    } else {
      console.warn('Toast.show() called before ToastProvider mounted');
    }
  };

// 导出 Toast 对象，便于在 React 组件中以 Toast.show() 形式调用
export const Toast = {
  show(message: string, type: ToastType = 'info') {
    if (externalShowToast) {
      externalShowToast(message, type);
    } else {
      console.warn('Toast.show() called before ToastProvider mounted');
    }
  },
};
