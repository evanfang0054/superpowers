import { useState } from 'react';

interface Spec {
  name: string;
  values: string[];
}

interface SpecSelectorProps {
  specs: Spec[];
  onChange: (selected: Record<string, string>) => void;
}

export function SpecSelector({ specs, onChange }: SpecSelectorProps) {
  const [selected, setSelected] = useState<Record<string, string>>({});

  const handleSelect = (specName: string, value: string) => {
    const next = { ...selected, [specName]: value };
    setSelected(next);
    onChange(next);
  };

  if (specs.length === 0) return null;

  return (
    <div className="px-5 pb-4 space-y-4">
      {specs.map((spec) => (
        <div key={spec.name}>
          <div className="text-sm font-bold text-brand-dark mb-2.5">{spec.name}</div>
          <div className="flex gap-2.5 flex-wrap">
            {spec.values.map((value) => {
              const isActive = selected[spec.name] === value;
              return (
                <div
                  key={value}
                  onClick={() => handleSelect(spec.name, value)}
                  className="py-2.5 px-[18px] rounded-2xl cursor-pointer transition-all duration-200"
                  style={{
                    border: isActive
                      ? '2.5px solid var(--color-brand-primary)'
                      : '2px solid var(--color-brand-border)',
                    background: isActive
                      ? 'color-mix(in srgb, var(--color-brand-primary) 6%, transparent)'
                      : 'var(--color-brand-card)',
                  }}
                >
                  <div
                    className={`text-sm font-semibold ${
                      isActive ? 'text-brand-primary' : 'text-brand-dark'
                    }`}
                  >
                    {value}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}
