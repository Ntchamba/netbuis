import { useId, type SelectHTMLAttributes } from "react";
import { cn } from "../../lib/cn";

export interface SelectOption {
  value: string;
  label: string;
}

interface SelectProps extends SelectHTMLAttributes<HTMLSelectElement> {
  label: string;
  error?: string;
  options: SelectOption[];
}

export function Select({ label, error, options, id, className, ...rest }: SelectProps) {
  const auto = useId();
  const fid = id ?? auto;
  return (
    <div className="flex flex-col gap-1">
      <label htmlFor={fid} className="text-[12px] font-bold text-ink-2">
        {label}
      </label>
      <select
        id={fid}
        aria-invalid={error ? true : undefined}
        aria-describedby={error ? `${fid}-erreur` : undefined}
        className={cn(
          "w-full rounded-[10px] border bg-card px-3 py-2 text-[13px] text-ink disabled:opacity-50",
          error ? "border-danger" : "border-line",
          className,
        )}
        {...rest}
      >
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
      {error && (
        <p id={`${fid}-erreur`} role="alert" className="text-[11.5px] text-danger">
          {error}
        </p>
      )}
    </div>
  );
}
