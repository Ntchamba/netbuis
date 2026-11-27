import { cn } from "../../../lib/cn";
import type { StatusFilter } from "../types";

const STATUS: Array<{ key: StatusFilter; label: string }> = [
  { key: "all", label: "Tous" },
  { key: "active", label: "Actifs" },
  { key: "inactive", label: "Désactivés" },
];

export function StatusFilterButtons({ value, onChange }: { value: StatusFilter; onChange: (v: StatusFilter) => void }) {
  return (
    <div role="group" aria-label="Filtrer par état" className="flex flex-wrap gap-2">
      {STATUS.map((s) => (
        <button
          key={s.key}
          type="button"
          aria-pressed={value === s.key}
          onClick={() => onChange(s.key)}
          className={cn(
            "cursor-pointer rounded-full border px-[15px] py-2 text-[12.5px] font-bold",
            value === s.key ? "border-accent bg-accent text-on-accent" : "border-line bg-transparent text-ink-2",
          )}
        >
          {s.label}
        </button>
      ))}
    </div>
  );
}

export function SearchBox({ label, value, onChange }: { label: string; value: string; onChange: (v: string) => void }) {
  return (
    <label className="flex w-60 items-center gap-2 rounded-[10px] border border-line bg-card px-3 py-2">
      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="shrink-0 text-ink-2" aria-hidden="true">
        <circle cx="11" cy="11" r="7" />
        <path d="M21 21l-4.3-4.3" />
      </svg>
      <input
        type="search"
        aria-label={label}
        placeholder={`${label}...`}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        autoComplete="off"
        className="w-full min-w-0 bg-transparent text-[12.5px] text-ink outline-none placeholder:text-ink-2"
      />
    </label>
  );
}
