import { formatInt } from "../../../lib/format";
import type { DayCount } from "../types";

const dayLabel = (iso: string) => {
  const [y, m, d] = iso.split("-");
  return y && m && d ? `${d}/${m}` : iso;
};

/**
 * Appels par jour : colonnes simples. Le graphique est décoratif (aria-hidden) ;
 * les mêmes chiffres sont dans le tableau « Détail par jour » juste dessous.
 */
export function CallsChart({ days }: { days: DayCount[] }) {
  const max = Math.max(1, ...days.map((d) => d.count));
  const total = days.reduce((s, d) => s + d.count, 0);
  return (
    <div>
      <p className="mb-2 text-[12px] text-ink-2">
        {formatInt(total)} appels sur {days.length} jours
      </p>
      <div aria-hidden="true" data-testid="calls-chart" className="flex h-36 items-end gap-0.5">
        {days.map((d) => (
          <div
            key={d.date}
            title={`${dayLabel(d.date)} : ${d.count}`}
            className="min-w-0 flex-1 rounded-t bg-accent"
            style={{ height: `${d.count === 0 ? 2 : Math.max(4, Math.round((d.count / max) * 100))}%`, opacity: d.count === 0 ? 0.3 : 1 }}
          />
        ))}
      </div>
      <details className="mt-3">
        <summary className="cursor-pointer text-[12.5px] font-semibold">Détail par jour</summary>
        <table className="mt-2 w-full text-[12.5px]">
          <caption className="sr-only">Appels par jour</caption>
          <thead>
            <tr className="text-left text-ink-3">
              <th scope="col" className="py-1">Jour</th>
              <th scope="col" className="py-1 text-right">Appels</th>
            </tr>
          </thead>
          <tbody>
            {days.map((d) => (
              <tr key={d.date} className="border-t border-line">
                <th scope="row" className="py-1 text-left font-normal">{dayLabel(d.date)}</th>
                <td className="py-1 text-right">{formatInt(d.count)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </details>
    </div>
  );
}
