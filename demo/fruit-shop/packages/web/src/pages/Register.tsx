import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '@/store/auth.store';
import { Toast } from '@/components/Toast';
import { Button } from '@/components/ui';

export default function Register() {
  const navigate = useNavigate();
  const { register, isLoading } = useAuthStore();

  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [nickname, setNickname] = useState('');

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();

    if (!phone.trim()) {
      Toast.show('请输入手机号', 'warning');
      return;
    }
    if (phone.trim().length !== 11) {
      Toast.show('请输入正确的手机号', 'warning');
      return;
    }
    if (!password.trim() || password.length < 6) {
      Toast.show('密码至少6位', 'warning');
      return;
    }

    try {
      await register({
        phone: phone.trim(),
        password,
        nickname: nickname.trim() || undefined,
      });
      Toast.show('注册成功', 'success');
      navigate('/', { replace: true });
    } catch {
      Toast.show('注册失败，手机号可能已被注册', 'error');
    }
  };

  return (
    <div className="min-h-screen bg-brand-bg flex flex-col">
      <header className="max-w-lg mx-auto w-full px-4 pt-16 pb-8">
        <h1 className="text-3xl font-bold text-brand-primary font-display">鲜果集</h1>
        <p className="text-brand-muted mt-2">创建账号，开启新鲜水果之旅</p>
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
              placeholder="请输入密码（至少6位）"
              className="w-full px-4 py-3 rounded-2xl border border-brand-border bg-white text-brand-dark placeholder-brand-muted/70 focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary transition-colors"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-brand-dark mb-1.5">
              昵称 <span className="text-brand-muted font-normal">（选填）</span>
            </label>
            <input
              type="text"
              value={nickname}
              onChange={(e) => setNickname(e.target.value)}
              placeholder="给自己取个名字吧"
              maxLength={20}
              className="w-full px-4 py-3 rounded-2xl border border-brand-border bg-white text-brand-dark placeholder-brand-muted/70 focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary transition-colors"
            />
          </div>

          <Button type="submit" loading={isLoading} fullWidth size="lg">
            {isLoading ? '注册中...' : '注册'}
          </Button>
        </form>

        <p className="text-center text-sm text-brand-muted mt-6">
          已有账号？
          <button
            onClick={() => navigate('/login')}
            className="text-brand-primary font-medium hover:underline ml-1"
          >
            立即登录
          </button>
        </p>
      </main>
    </div>
  );
}
