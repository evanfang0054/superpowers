import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Avatar } from '@/components/Avatar';
import { TabBar } from '@/components/TabBar';
import { Button } from '@/components/ui';
import { useAuthStore } from '@/store/auth.store';
import { userApi } from '@/api/user';
import { useToast } from '@/components/Toast';

export default function Profile() {
  const navigate = useNavigate();
  const user = useAuthStore((s) => s.user);
  const { showToast } = useToast();
  const [isEditing, setIsEditing] = useState(false);
  const [nickname, setNickname] = useState(user?.nickname ?? '');
  const [saving, setSaving] = useState(false);

  // ProtectedRoute 已保证 token 存在，但 refreshUserInfo 可能未完成时 user 暂为旧值/null
  if (!user) return null;

  const maskedPhone = user.phone.slice(0, 3) + '****' + user.phone.slice(-4);
  const isAdmin = user.role === 'admin';

  const handleSave = async () => {
    setSaving(true);
    try {
      const { data } = await userApi.updateProfile({ nickname });
      useAuthStore.setState({ user: data.data! });
      showToast('资料已更新', 'success');
      setIsEditing(false);
    } catch {
      showToast('更新失败，请重试', 'error');
    } finally {
      setSaving(false);
    }
  };

  const handleCancel = () => {
    setNickname(user.nickname ?? '');
    setIsEditing(false);
  };

  const handleLogout = async () => {
    await useAuthStore.getState().logout();
    navigate('/login', { replace: true });
  };

  return (
    <div className="min-h-screen bg-brand-bg pb-20">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-brand-bg/90 backdrop-blur-[10px] border-b border-brand-border px-4 py-3">
        <h1 className="text-[22px] font-black text-brand-dark">个人中心</h1>
      </header>

      {/* 主卡片 */}
      <div className="px-4 py-6">
        <div className="bg-white rounded-3xl border border-brand-border p-6 flex flex-col items-center gap-3">
          <Avatar src={user.avatar} alt={user.nickname ?? user.phone} size={72} />

          {isEditing ? (
            <div className="flex flex-col items-center gap-3 w-full">
              <input
                value={nickname}
                onChange={(e) => setNickname(e.target.value)}
                maxLength={50}
                autoFocus
                placeholder="输入昵称"
                className="text-center text-[18px] font-bold border border-brand-border rounded-2xl px-3 py-2 w-full max-w-[220px] focus:outline-none focus:border-brand-primary"
              />
              <div className="flex gap-2">
                <Button
                  variant="primary"
                  size="sm"
                  disabled={saving || nickname.trim().length === 0}
                  onClick={handleSave}
                >
                  {saving ? '保存中...' : '保存'}
                </Button>
                <Button variant="ghost" size="sm" disabled={saving} onClick={handleCancel}>
                  取消
                </Button>
              </div>
            </div>
          ) : (
            <>
              <div className="text-[22px] font-black text-brand-dark">
                {user.nickname ?? `用户${user.phone.slice(-4)}`}
              </div>
              <div className="text-[13px] text-brand-muted">📱 {maskedPhone}</div>
              {isAdmin && (
                <span className="px-2 py-0.5 rounded-md bg-brand-peach text-brand-primary text-[11px] font-bold">
                  管理员
                </span>
              )}
              <Button
                variant="primary"
                fullWidth={false}
                className="mt-2 w-full max-w-[220px]"
                onClick={() => {
                  setNickname(user.nickname ?? '');
                  setIsEditing(true);
                }}
              >
                编辑资料
              </Button>
            </>
          )}
        </div>

        {/* 登出按钮 */}
        <div className="mt-4 bg-white rounded-3xl border border-brand-border overflow-hidden">
          <button
            onClick={() => navigate('/addresses')}
            className="w-full px-4 py-3.5 flex items-center justify-between text-sm text-brand-dark hover:bg-brand-bg"
          >
            <span className="flex items-center gap-2">
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                className="text-brand-primary"
              >
                <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z" />
                <circle cx="12" cy="10" r="3" />
              </svg>
              我的地址
            </span>
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              className="text-brand-muted"
            >
              <path d="M9 18l6-6-6-6" />
            </svg>
          </button>
          <div className="border-t border-brand-border" />
          <button
            onClick={() => navigate('/favorites')}
            className="w-full px-4 py-3.5 flex items-center justify-between text-sm text-brand-dark hover:bg-brand-bg"
          >
            <span className="flex items-center gap-2">
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                className="text-brand-accent"
              >
                <path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z" />
              </svg>
              我的收藏
            </span>
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              className="text-brand-muted"
            >
              <path d="M9 18l6-6-6-6" />
            </svg>
          </button>
          <div className="border-t border-brand-border" />
          <button
            onClick={() => navigate('/coupons/mine')}
            className="w-full px-4 py-3.5 flex items-center justify-between text-sm text-brand-dark hover:bg-brand-bg"
          >
            <span className="flex items-center gap-2">
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                className="text-brand-secondary"
              >
                <path d="M20 12V8H4v4a2 2 0 010 4v4h16v-4a2 2 0 010-4z" />
                <path d="M10 8v8" strokeDasharray="2 2" />
              </svg>
              我的优惠券
            </span>
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              className="text-brand-muted"
            >
              <path d="M9 18l6-6-6-6" />
            </svg>
          </button>
        </div>

        <button
          onClick={handleLogout}
          className="mt-4 w-full py-3 rounded-2xl border border-brand-coral text-brand-coral text-sm font-bold bg-white"
        >
          退出登录
        </button>
      </div>

      <TabBar />
    </div>
  );
}
