import { cn } from "../../lib/cn";

export function Spinner({ size = 20, label }: { size?: number; label?: string }) {
  return (
    <span
      role={label ? "status" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      style={{ width: size, height: size }}
      className="inline-block animate-spin rounded-full border-2 border-current border-t-transparent"
    />
  );
}

/** Bloc gris pulsant pour les états de chargement. */
export function Skeleton({ className }: { className?: string }) {
  return <div aria-hidden="true" data-skeleton className={cn("animate-pulse rounded-md bg-line", className)} />;
}
