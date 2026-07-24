import { useState, useEffect, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { addressApi } from '@/api/address';
import type { Address, CreateAddressDTO } from 'shared';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { Toast } from '@/components/Toast';

interface FormState {
  recipientName: string;
  phone: string;
  province: string;
  city: string;
  district: string;
  detail: string;
  isDefault: boolean;
}

const EMPTY_FORM: FormState = {
  recipientName: '',
  phone: '',
  province: '',
  city: '',
  district: '',
  detail: '',
  isDefault: false,
};

export default function Addresses() {
  const navigate = useNavigate();
  const [list, setList] = useState<Address[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<Address | null>(null);
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [saving, setSaving] = useState(false);

  const fetchList = async () => {
    setLoading(true);
    try {
      const { data } = await addressApi.getList();
      setList(data.data ?? []);
    } catch {
      Toast.show('加载地址失败', 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchList();
  }, []);

  const openCreate = () => {
    setEditing(null);
    setForm(EMPTY_FORM);
    setShowModal(true);
  };

  const openEdit = (addr: Address) => {
    setEditing(addr);
    setForm({
      recipientName: addr.recipientName,
      phone: addr.phone,
      province: addr.province,
      city: addr.city,
      district: addr.district,
      detail: addr.detail,
      isDefault: addr.isDefault,
    });
    setShowModal(true);
  };

  const closeForm = () => {
    setShowModal(false);
    setEditing(null);
    setForm(EMPTY_FORM);
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    const payload: CreateAddressDTO = {
      recipientName: form.recipientName.trim(),
      phone: form.phone.trim(),
      province: form.province.trim(),
      city: form.city.trim(),
      district: form.district.trim(),
      detail: form.detail.trim(),
      isDefault: form.isDefault,
    };

    if (!payload.recipientName || !payload.phone || !payload.detail) {
      Toast.show('请填写收货人、手机号和详细地址', 'warning');
      return;
    }
    if (!/^1\d{10}$/.test(payload.phone)) {
      Toast.show('请输入正确的手机号', 'warning');
      return;
    }

    setSaving(true);
    try {
      if (editing) {
        await addressApi.update(editing.id, payload);
        Toast.show('地址已更新', 'success');
      } else {
        await addressApi.create(payload);
        Toast.show('地址已添加', 'success');
      }
      await fetchList();
      closeForm();
    } catch {
      Toast.show('保存失败，请重试', 'error');
    } finally {
      setSaving(false);
    }
  };

  const handleSetDefault = async (addr: Address) => {
    if (addr.isDefault) return;
    try {
      await addressApi.setDefault(addr.id);
      Toast.show('已设为默认', 'success');
      await fetchList();
    } catch {
      Toast.show('操作失败', 'error');
    }
  };

  const handleRemove = async (addr: Address) => {
    if (!window.confirm('确定删除该地址？')) return;
    try {
      await addressApi.remove(addr.id);
      Toast.show('已删除', 'success');
      await fetchList();
    } catch {
      Toast.show('删除失败', 'error');
    }
  };

  return (
    <div className="min-h-screen bg-brand-bg pb-24">
      {/* Header */}
      <header className="sticky top-0 z-30 bg-white/90 backdrop-blur-sm border-b border-brand-border">
        <div className="max-w-lg mx-auto px-4 py-3 flex items-center gap-3">
          <button
            onClick={() => navigate(-1)}
            className="w-9 h-9 flex items-center justify-center rounded-full bg-brand-btn-bg hover:bg-brand-border transition-colors"
          >
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
            >
              <path d="M19 12H5M12 19l-7-7 7-7" />
            </svg>
          </button>
          <h1 className="text-lg font-bold text-brand-dark">收货地址</h1>
        </div>
      </header>

      <main className="max-w-lg mx-auto px-4 mt-3 space-y-3">
        {loading ? (
          <div className="flex justify-center py-10">
            <LoadingSpinner size="lg" />
          </div>
        ) : list.length === 0 ? (
          <div className="bg-white rounded-2xl border border-brand-border p-8 text-center">
            <p className="text-sm text-brand-muted">还没有收货地址</p>
            <button
              onClick={openCreate}
              className="mt-4 px-6 py-2 rounded-full bg-gradient-to-br from-brand-primary to-brand-coral text-white text-sm font-bold"
            >
              新增地址
            </button>
          </div>
        ) : (
          list.map((addr) => (
            <div key={addr.id} className="bg-white rounded-2xl border border-brand-border p-4">
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <span className="text-[15px] font-bold text-brand-dark">
                      {addr.recipientName}
                    </span>
                    <span className="text-[13px] text-brand-muted">{addr.phone}</span>
                    {addr.isDefault && (
                      <span className="px-1.5 py-0.5 rounded-md bg-brand-peach text-brand-primary text-[10px] font-bold">
                        默认
                      </span>
                    )}
                  </div>
                  <p className="mt-1 text-[13px] text-brand-dark leading-relaxed">
                    {addr.province}
                    {addr.city}
                    {addr.district}
                    {addr.detail}
                  </p>
                </div>
              </div>
              <div className="mt-3 flex items-center gap-2 border-t border-brand-border pt-2.5">
                {!addr.isDefault && (
                  <button
                    onClick={() => handleSetDefault(addr)}
                    className="px-3 py-1 text-[12px] rounded-full border border-brand-border text-brand-dark hover:bg-brand-bg"
                  >
                    设为默认
                  </button>
                )}
                <button
                  onClick={() => openEdit(addr)}
                  className="px-3 py-1 text-[12px] rounded-full border border-brand-border text-brand-dark hover:bg-brand-bg"
                >
                  编辑
                </button>
                <button
                  onClick={() => handleRemove(addr)}
                  className="px-3 py-1 text-[12px] rounded-full border border-brand-coral text-brand-coral hover:bg-brand-coral/5"
                >
                  删除
                </button>
              </div>
            </div>
          ))
        )}
      </main>

      {/* 底部新增按钮 */}
      {!loading && list.length > 0 && (
        <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-brand-border z-40 safe-bottom">
          <div className="max-w-lg mx-auto px-4 py-3">
            <button
              onClick={openCreate}
              className="w-full py-2.5 text-sm font-bold text-white bg-gradient-to-br from-brand-primary to-brand-coral rounded-full"
            >
              新增收货地址
            </button>
          </div>
        </div>
      )}

      {/* 新增/编辑 modal */}
      {showModal && (
        <div className="fixed inset-0 z-[60] bg-black/40 flex items-end sm:items-center justify-center">
          <div className="bg-white rounded-t-3xl sm:rounded-3xl w-full max-w-lg p-5 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-base font-bold text-brand-dark">
                {editing ? '编辑地址' : '新增地址'}
              </h3>
              <button
                onClick={closeForm}
                className="w-7 h-7 flex items-center justify-center rounded-full bg-brand-btn-bg text-brand-dark"
              >
                &times;
              </button>
            </div>
            <form onSubmit={handleSubmit} className="space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <Field
                  label="收货人"
                  value={form.recipientName}
                  onChange={(v) => setForm({ ...form, recipientName: v })}
                  placeholder="姓名"
                />
                <Field
                  label="手机号"
                  value={form.phone}
                  onChange={(v) => setForm({ ...form, phone: v })}
                  placeholder="11 位手机号"
                  maxLength={11}
                />
              </div>
              <div className="grid grid-cols-3 gap-3">
                <Field
                  label="省"
                  value={form.province}
                  onChange={(v) => setForm({ ...form, province: v })}
                  placeholder="省份"
                />
                <Field
                  label="市"
                  value={form.city}
                  onChange={(v) => setForm({ ...form, city: v })}
                  placeholder="城市"
                />
                <Field
                  label="区/县"
                  value={form.district}
                  onChange={(v) => setForm({ ...form, district: v })}
                  placeholder="区/县"
                />
              </div>
              <div>
                <label className="block text-[12px] text-brand-muted mb-1">详细地址</label>
                <textarea
                  value={form.detail}
                  onChange={(e) => setForm({ ...form, detail: e.target.value })}
                  rows={2}
                  placeholder="街道、楼栋、门牌号"
                  className="w-full px-3 py-2 rounded-2xl border border-brand-border bg-brand-bg text-[13px] focus:outline-none focus:border-brand-primary resize-none"
                />
              </div>
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={form.isDefault}
                  onChange={(e) => setForm({ ...form, isDefault: e.target.checked })}
                  className="w-4 h-4 accent-brand-primary"
                />
                <span className="text-[13px] text-brand-dark">设为默认地址</span>
              </label>
              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={closeForm}
                  disabled={saving}
                  className="flex-1 py-2.5 text-sm font-bold rounded-full border border-brand-border text-brand-dark"
                >
                  取消
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="flex-1 py-2.5 text-sm font-bold rounded-full bg-gradient-to-br from-brand-primary to-brand-coral text-white disabled:opacity-50"
                >
                  {saving ? '保存中...' : '保存'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

interface FieldProps {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  maxLength?: number;
}

function Field({ label, value, onChange, placeholder, maxLength }: FieldProps) {
  return (
    <div>
      <label className="block text-[12px] text-brand-muted mb-1">{label}</label>
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        maxLength={maxLength}
        className="w-full px-3 py-2 rounded-2xl border border-brand-border bg-brand-bg text-[13px] focus:outline-none focus:border-brand-primary"
      />
    </div>
  );
}
