import { Card, EmptyState } from "../../../components/ui";
import { formatInt } from "../../../lib/format";
import type { AdminStats } from "../types";

/** Nom et appels par jour seulement : le numéro n'est jamais affiché. */
export function HighTrafficCard({ stats }: { stats: AdminStats }) {
  const list = stats.high_traffic;
  const more = stats.high_traffic_count - list.length;
  return (
    <Card className="border-warn-line">
      <h2 className="mb-1.5 text-[14.5px] font-extrabold">Comptes à fort trafic, non abonnés</h2>
      <p className="mb-3.5 text-xs text-ink-2">
        Plus de {formatInt(stats.subscription_threshold)} appels reçus sur 24 h — candidats naturels pour l'abonnement
      </p>
      {list.length === 0 ? (
        <EmptyState title="Aucun compte au-dessus du seuil" />
      ) : (
        <ul className="m-0 flex list-none flex-col gap-2 p-0">
          {list.map((b) => (
            <li key={b.id} className="flex items-center justify-between gap-3">
              <span className="truncate text-[13px] font-semibold">{b.name}</span>
              <span className="shrink-0 text-[12.5px] font-extrabold text-accent-ink">{formatInt(b.calls_per_day)} appels/jour</span>
            </li>
          ))}
        </ul>
      )}
      {more > 0 && <p className="mt-3 text-xs text-ink-3">et {formatInt(more)} autres comptes</p>}
    </Card>
  );
}
