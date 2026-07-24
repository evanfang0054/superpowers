import { useRef, useState } from 'react';
import { apiClient } from '@/api/client';
import { Toast } from '@/components/Toast';

interface UploadButtonProps {
  value: string;
  onChange: (url: string) => void;
  accept?: string;
}

/**
 * 图片上传按钮：包装 input[type=file]，调用 /upload/image，
 * 将返回的 url 写回表单字段，并显示预览。
 */
export function UploadButton({ value, onChange, accept = 'image/*' }: UploadButtonProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);

  const handleFile = async (file: File) => {
    if (!file) return;
    setUploading(true);
    try {
      const form = new FormData();
      form.append('file', file);
      const { data } = await apiClient.post('/upload/image', form, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      if (data?.code === 0 && data?.data?.url) {
        onChange(data.data.url);
      } else {
        Toast.show(data?.message ?? '上传失败', 'error');
      }
    } catch {
      Toast.show('上传失败', 'error');
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="flex items-center gap-3">
      <button
        type="button"
        onClick={() => inputRef.current?.click()}
        disabled={uploading}
        className="px-3 py-2 text-sm border border-brand-border rounded-2xl text-brand-dark hover:bg-brand-bg disabled:opacity-50"
      >
        {uploading ? '上传中...' : '选择图片'}
      </button>
      <input
        ref={inputRef}
        type="file"
        accept={accept}
        className="hidden"
        onChange={(e) => {
          const f = e.target.files?.[0];
          if (f) handleFile(f);
          // 重置 value，允许重复选择同一文件
          e.target.value = '';
        }}
      />
      {value && (
        <div className="w-12 h-12 rounded-2xl overflow-hidden bg-brand-btn-bg flex-shrink-0">
          <img src={value} alt="preview" className="w-full h-full object-cover" />
        </div>
      )}
    </div>
  );
}
