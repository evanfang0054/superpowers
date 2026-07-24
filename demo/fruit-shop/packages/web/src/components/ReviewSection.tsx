import { useState, useEffect, useCallback } from 'react';
import { reviewApi } from '@/api/review';
import type { ReviewWithUser } from 'shared';
import { Avatar } from '@/components/Avatar';
import { LoadingSpinner } from '@/components/LoadingSpinner';

interface ReviewSectionProps {
  productId: number;
}

const PAGE_SIZE = 5;

function StarRow({ rating }: { rating: number }) {
  return (
    <div className="flex items-center gap-0.5">
      {[1, 2, 3, 4, 5].map((n) => (
        <svg
          key={n}
          width="13"
          height="13"
          viewBox="0 0 24 24"
          fill={n <= rating ? '#FF6B35' : 'none'}
          stroke={n <= rating ? '#FF6B35' : '#636E72'}
          strokeWidth="2"
        >
          <polygon points="12,2 15,9 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 9,9" />
        </svg>
      ))}
    </div>
  );
}

function formatDate(iso: string) {
  try {
    return new Date(iso).toLocaleDateString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
  } catch {
    return '';
  }
}

export function ReviewSection({ productId }: ReviewSectionProps) {
  const [reviews, setReviews] = useState<ReviewWithUser[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);

  const fetchPage = useCallback(
    async (targetPage: number) => {
      setLoading(true);
      try {
        const { data } = await reviewApi.getByProduct(productId, {
          page: targetPage,
          limit: PAGE_SIZE,
        });
        const payload = data.data;
        setReviews(payload?.list ?? []);
        setTotal(payload?.total ?? 0);
        setPage(targetPage);
      } catch {
        setReviews([]);
        setTotal(0);
      } finally {
        setLoading(false);
      }
    },
    [productId],
  );

  useEffect(() => {
    fetchPage(1);
  }, [fetchPage]);

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  return (
    <section className="px-5 pb-6">
      <div className="flex items-center justify-between mb-3">
        <h2 className="text-sm font-bold text-brand-dark">
          用户评价
          {total > 0 && <span className="ml-1.5 text-brand-muted font-medium">({total})</span>}
        </h2>
      </div>

      {loading ? (
        <div className="flex justify-center py-6">
          <LoadingSpinner size="md" />
        </div>
      ) : reviews.length === 0 ? (
        <div className="bg-white rounded-2xl border border-brand-border p-5 text-center">
          <p className="text-[13px] text-brand-muted">暂无评价，快来抢沙发</p>
        </div>
      ) : (
        <div className="space-y-3">
          {reviews.map((r) => (
            <div key={r.id} className="bg-white rounded-2xl border border-brand-border p-3.5">
              <div className="flex items-center gap-2.5">
                <Avatar src={r.userAvatar} alt={r.userNickname ?? '用户'} size={32} />
                <div className="flex-1 min-w-0">
                  <div className="text-[13px] font-bold text-brand-dark line-clamp-1">
                    {r.userNickname ?? `用户${r.userId.toString().slice(-4)}`}
                  </div>
                  <StarRow rating={r.rating} />
                </div>
                <span className="text-[11px] text-brand-muted">{formatDate(r.createdAt)}</span>
              </div>
              {r.content && (
                <p className="mt-2 text-[13px] text-brand-dark leading-relaxed whitespace-pre-wrap break-words">
                  {r.content}
                </p>
              )}
            </div>
          ))}
        </div>
      )}

      {totalPages > 1 && !loading && (
        <div className="mt-4 flex items-center justify-center gap-3">
          <button
            onClick={() => fetchPage(Math.max(1, page - 1))}
            disabled={page <= 1}
            className="px-3 py-1.5 text-[12px] rounded-full border border-brand-border text-brand-dark disabled:opacity-40"
          >
            上一页
          </button>
          <span className="text-[12px] text-brand-muted">
            {page} / {totalPages}
          </span>
          <button
            onClick={() => fetchPage(Math.min(totalPages, page + 1))}
            disabled={page >= totalPages}
            className="px-3 py-1.5 text-[12px] rounded-full border border-brand-border text-brand-dark disabled:opacity-40"
          >
            下一页
          </button>
        </div>
      )}
    </section>
  );
}
