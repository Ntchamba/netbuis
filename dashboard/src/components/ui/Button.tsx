import type { ButtonHTMLAttributes } from "react";
import { cn } from "../../lib/cn";
import { Spinner } from "./Spinner";

export type ButtonVariant = "primary" | "secondary" | "danger" | "ghost";

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  loading?: boolean;
}

const VARIANTS: Record<ButtonVariant, string> = {
  primary: "bg-accent text-on-accent border border-accent",
  secondary: "bg-transparent text-ink-2 border border-line",
  danger: "bg-transparent text-danger border border-danger",
  ghost: "bg-transparent text-ink-2 border border-transparent",
};

export function Button({ variant = "primary", loading = false, disabled, className, children, type = "button", ...rest }: ButtonProps) {
  return (
    <button
      type={type}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      className={cn(
        "inline-flex cursor-pointer items-center justify-center gap-2 rounded-[9px] px-4 py-2 text-[12.5px] font-bold disabled:cursor-not-allowed disabled:opacity-50",
        VARIANTS[variant],
        className,
      )}
      {...rest}
    >
      {loading && <Spinner size={14} />}
      {children}
    </button>
  );
}
