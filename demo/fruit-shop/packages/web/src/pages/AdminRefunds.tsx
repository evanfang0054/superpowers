import { useState, useEffect } from 'react';
import { refundApi } from '@/api/refund';
import type { Refund } from 'shared';
import { RefundStatus } from 'shared';
import { useToast } from '@/components/Toast';

export default function AdminRefunds() {
  const { showToast } = useToast();
  const [refunds, setRefunds] = useState<Refund[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [rejectTarget, setRejectTarget] = useState<Refund | null>(null);
  const [adminNote, setAdminNote] = useState('');

  const fetchRefunds = async () => {
    setIsLoading(true);
    try {
      const { data } = await refundApi.list({ page: 1, limit: 50 });
      setRefunds(data.data?.list ?? []);
    } catch {
      showToast('加载失败', 'error');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchRefunds();
  }, []);

  const handleApprove = async (id: number) => {
    if (!confirm('确定通过此退款申请？')) return;
    try {
      await refundApi.approve(id);
      showToast('已通过', 'success');
      fetchRefunds();
    } catch {
      showToast('操作失败', 'error');
    }
  };

  const openReject = (r: Refund) => {
    setRejectTarget(r);
    setAdminNote('');
  };

  const handleReject = async () => {
    if (!rejectTarget) return;
    if (!adminNote.trim()) {
      showToast('请填写驳回原因', 'error');
      return;
    }
    try {
      await refundApi.reject(rejectTarget.id, adminNote.trim());
      showToast('已拒绝', 'success');
      setRejectTarget(null);
      fetchRefunds();
    } catch {
      showToast('操作失败', 'error');
    }
  };

  const renderStatus = (status: RefundStatus) => {
    const map: Record<RefundStatus, { label: string; cls: string }> = {
      [RefundStatus.PENDING]: {
        label: '待审批',
        cls: 'bg-yellow-100 text-yellow-700',
      },
      [RefundStatus.APPROVED]: {
        label: '已通过',
        cls: 'bg-green-100 text-green-700',
      },
      [RefundStatus.REJECTED]: {
        label: '已拒绝',
        cls: 'bg-red-100 text-red-700',
      },
    };
    const s = map[status];
    return <span className={`px-2 py-0.5 rounded text-xs font-bold ${s.cls}`}>{s.label}</span>;
  };

  return (
    <div className="min-h-screen bg-brand-bg p-6">
      <header className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-brand-dark">退款审批</h1>
      </header>

      {isLoading ? (
        <div className="text-center py-10 text-brand-muted">加载中...</div>
      ) : refunds.length === 0 ? (
        <div className="text-center py-10 text-brand-muted">暂无退款申请</div>
      ) : (
        <table className="w-full bg-brand-card rounded-2xl border border-brand-border">
          <thead className="bg-brand-btn-bg text-brand-muted text-sm">
            <tr>
              <th className="text-left p-3">退款单号</th>
              <th className="text-left p-3">订单号</th>
              <th className="text-left p-3">用户ID</th>
              <th className="text-left p-3">申请原因</th>
              <th className="text-left p-3">状态</th>
              <th className="text-left p-3">操作</th>
            </tr>
          </thead>
          <tbody>
            {refunds.map((r) => (
              <tr key={r.id} className="border-t border-brand-border">
                <td className="p-3 font-medium">#{r.id}</td>
                <td className="p-3">#{r.orderId}</td>
                <td className="p-3">{r.userId}</td>
                <td className="p-3 text-sm text-brand-dark max-w-xs truncate">{r.reason}</td>
                <td className="p-3">{renderStatus(r.status)}</td>
                <td className="p-3 flex gap-3">
                  {r.status === RefundStatus.PENDING ? (
                    <>
                      <button
                        onClick={() => handleApprove(r.id)}
                        className="text-brand-primary text-sm font-bold"
                      >
                        通过
                      </button>
                      <button
                        onClick={() => openReject(r)}
                        className="text-red-500 text-sm font-bold"
                      >
                        拒绝
                      </button>
                    </>
                  ) : (
                    <span className="text-xs text-brand-muted">
                      {r.adminNote ? `备注：${r.adminNote}` : '—'}
                    </span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {rejectTarget && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
          <div className="bg-brand-card rounded-3xl p-6 w-full max-w-md">
            <h2 className="text-xl font-bold mb-2">拒绝退款申请</h2>
            <p className="text-sm text-brand-muted mb-4">
              退款单 #{rejectTarget.id}（订单 #{rejectTarget.orderId}）
            </p>
            <textarea
              value={adminNote}
              onChange={(e) => setAdminNote(e.target.value)}
              placeholder="请填写驳回原因（必填）"
              rows={4}
              className="w-full border border-brand-border rounded-2xl px-3 py-2 focus:ring-2 focus:ring-brand-primary/30 resize-none"
            />
            <div className="flex gap-2 mt-6">
              <button
                onClick={handleReject}
                className="flex-1 py-2.5 rounded-2xl bg-red-500 text-white font-bold"
              >
                确认拒绝
              </button>
              <button
                onClick={() => setRejectTarget(null)}
                className="flex-1 py-2.5 rounded-2xl border border-brand-border font-bold"
              >
                取消
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
