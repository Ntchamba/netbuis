import type { ReactNode } from "react";

export function EmptyState({ title, description, action }: { title: string; description?: string; action?: ReactNode }) {
  return (
    <div className="flex flex-col items-center gap-2 px-6 py-10 text-center">
      <p className="text-[14px] font-bold text-ink">{title}</p>
      {description && <p className="text-[12.5px] text-ink-2">{description}</p>}
      {action}
    </div>
  );
}
