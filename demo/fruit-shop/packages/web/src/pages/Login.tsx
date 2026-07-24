import { useState, type FormEvent } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuthStore } from '@/store/auth.store';
import { Toast } from '@/components/Toast';
import { Button } from '@/components/ui';

export default function Login() {
  const navigate = useNavigate();
  const location = useLocation();
  const { login, isLoading } = useAuthStore();

  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');

  const from = (location.state as { from?: { pathname: string } })?.from?.pathname || '/';

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();

    if (!phone.trim()) {
      Toast.show('请输入手机号', 'warning');
      return;
    }
    if (!password.trim()) {
      Toast.show('请输入密码', 'warning');
      return;
    }

    try {
      await login({ phone: phone.trim(), password });
      Toast.show('登录成功', 'success');
      navigate(from, { replace: true });
    } catch {
      Toast.show('手机号或密码错误', 'error');
    }
  };

  return (
    <div className="min-h-screen bg-brand-bg flex flex-col">
      <header className="max-w-lg mx-auto w-full px-4 pt-16 pb-8">
        <h1 className="text-3xl font-bold text-brand-primary font-display">鲜果集</h1>
        <p className="text-brand-muted mt-2">登录以享受新鲜水果配送服务</p>
      </header>

      <main className="max-w-lg mx-auto w-full px-4 flex-1">
        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-brand-dark mb-1.5">手机号</label>
            <input
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="请输入手机号"
              maxLength={11}
              className="w-full px-4 py-3 rounded-2xl border border-brand-border bg-white text-brand-dark placeholder-brand-muted/70 focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary transition-colors"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-brand-dark mb-1.5">密码</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="请输入密码"
              className="w-full px-4 py-3 rounded-2xl border border-brand-border bg-white text-brand-dark placeholder-brand-muted/70 focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary transition-colors"
            />
          </div>

          <Button type="submit" loading={isLoading} fullWidth size="lg">
            {isLoading ? '登录中...' : '登录'}
          </Button>
        </form>

        <p className="text-center text-sm text-brand-muted mt-6">
          还没有账号？
          <button
            onClick={() => navigate('/register')}
            className="text-brand-primary font-medium hover:underline ml-1"
          >
            立即注册
          </button>
        </p>
      </main>
    </div>
  );
}
