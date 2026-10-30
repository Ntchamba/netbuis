import { useId, type InputHTMLAttributes, type TextareaHTMLAttributes } from "react";
import { cn } from "../../lib/cn";

const FIELD =
  "w-full rounded-[10px] border bg-card px-3 py-2 text-[13px] text-ink placeholder:text-ink-2 disabled:opacity-50";

interface FieldProps {
  label: string;
  error?: string;
}

function Field({ id, label, error, children }: FieldProps & { id: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-1">
      <label htmlFor={id} className="text-[12px] font-bold text-ink-2">
        {label}
      </label>
      {children}
      {error && (
        <p id={`${id}-erreur`} role="alert" className="text-[11.5px] text-danger">
          {error}
        </p>
      )}
    </div>
  );
}

export function Input({ label, error, id, className, ...rest }: FieldProps & InputHTMLAttributes<HTMLInputElement>) {
  const auto = useId();
  const fid = id ?? auto;
  return (
    <Field id={fid} label={label} error={error}>
      <input
        id={fid}
        aria-invalid={error ? true : undefined}
        aria-describedby={error ? `${fid}-erreur` : undefined}
        className={cn(FIELD, error ? "border-danger" : "border-line", className)}
        {...rest}
      />
    </Field>
  );
}

export function Textarea({ label, error, id, className, ...rest }: FieldProps & TextareaHTMLAttributes<HTMLTextAreaElement>) {
  const auto = useId();
  const fid = id ?? auto;
  return (
    <Field id={fid} label={label} error={error}>
      <textarea
        id={fid}
        aria-invalid={error ? true : undefined}
        aria-describedby={error ? `${fid}-erreur` : undefined}
        className={cn(FIELD, "min-h-[88px] resize-y", error ? "border-danger" : "border-line", className)}
        {...rest}
      />
    </Field>
  );
}
