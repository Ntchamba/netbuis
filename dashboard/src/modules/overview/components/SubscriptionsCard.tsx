import { Card } from "../../../components/ui";
import { formatInt } from "../../../lib/format";
import type { AdminStats } from "../types";

export function SubscriptionsCard({ stats }: { stats: AdminStats }) {
  const pct = stats.active_businesses > 0 ? Math.round((stats.subscribers / stats.active_businesses) * 100) : 0;
  return (
    <Card>
      <h2 className="mb-1.5 text-[14.5px] font-extrabold">Abonnements</h2>
      <p className="mb-3.5 text-xs text-ink-2">Optionnel — ne change pas la visibilité d'un compte business actif</p>
      <div className="flex items-center gap-3.5">
        <div className="text-2xl font-extrabold">{formatInt(stats.subscribers)}</div>
        <div className="flex-1">
          <div className="mb-1.5 text-xs text-ink-2">
            comptes abonnés sur {formatInt(stats.active_businesses)} actifs ({pct}&nbsp;%)
          </div>
          <div
            role="progressbar"
            aria-label="Part des comptes abonnés"
            aria-valuemin={0}
            aria-valuemax={100}
            aria-valuenow={pct}
            className="h-2 overflow-hidden rounded-full bg-bg"
          >
            <div className="h-full rounded-full bg-accent" style={{ width: `${Math.min(pct, 100)}%` }} />
          </div>
        </div>
      </div>
      <p className="mt-3.5 text-xs text-ink-2">Seuil d'abonnement : {formatInt(stats.subscription_threshold)} appels par jour</p>
    </Card>
  );
}
