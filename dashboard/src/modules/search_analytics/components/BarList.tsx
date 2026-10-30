import { formatInt } from "../../../lib/format";

export interface BarItem {
  key: string;
  label: string;
  value: number;
}

/** Graphique à barres horizontales simple. Chaque valeur est aussi écrite en texte (lisible sans la vue). */
export function BarList({ items, label }: { items: BarItem[]; label: string }) {
  const max = Math.max(1, ...items.map((i) => i.value));
  return (
    <ul aria-label={label} className="flex flex-col gap-2.5">
      {items.map((i) => (
        <li key={i.key} className="flex flex-col gap-1" data-testid={`bar-${i.key}`}>
          <div className="flex items-baseline justify-between gap-3 text-[13px]">
            <span className="min-w-0 break-words">{i.label}</span>
            <strong className="shrink-0">{formatInt(i.value)}</strong>
          </div>
          <div aria-hidden="true" className="h-2 rounded-full bg-line">
            <div className="h-2 rounded-full bg-accent" style={{ width: `${Math.round((i.value / max) * 100)}%` }} />
          </div>
        </li>
      ))}
    </ul>
  );
}
