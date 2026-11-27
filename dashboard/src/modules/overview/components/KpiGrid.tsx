import { Card, Skeleton } from "../../../components/ui";
import { cn } from "../../../lib/cn";
import { formatInt } from "../../../lib/format";
import { formatMoney } from "../../../lib/money";
import type { AdminStats } from "../types";

function Kpi({ label, value, hint, hintClass = "text-ink-3", valueClass }: { label: string; value: string; hint: string; hintClass?: string; valueClass?: string }) {
  return (
    <Card className="p-[18px]">
      <div className="text-[12.5px] text-ink-2">{label}</div>
      <div className={cn("mt-1.5 text-[26px] font-extrabold", valueClass)}>{value}</div>
      <div className={cn("mt-1 text-[11.5px]", hintClass)}>{hint}</div>
    </Card>
  );
}

export function KpiGrid({ stats }: { stats: AdminStats }) {
  const rev = stats.revenue_month;
  return (
    <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-2 min-[1100px]:grid-cols-4">
      <Kpi label="Comptes au total" value={formatInt(stats.accounts_total)} hint={`+${formatInt(stats.accounts_new_week)} cette semaine`} hintClass="text-success" />
      <Kpi
        label="Comptes business actifs"
        value={formatInt(stats.active_businesses)}
        hint={`dans ${formatInt(stats.neighborhoods_covered)} ${stats.neighborhoods_covered > 1 ? "quartiers" : "quartier"}`}
      />
      <Kpi label="Demandes en attente" value={formatInt(stats.pending_requests)} valueClass="text-warn" hint="comptes business" />
      {rev.unavailable ? (
        <Kpi label="Revenus du mois" value="—" hint="paiements non activés" />
      ) : (
        <Kpi label="Revenus du mois" value={formatMoney(rev.amount, rev.currency)} hint="crédits + abonnements" />
      )}
    </div>
  );
}

export function KpiGridSkeleton() {
  return (
    <div data-testid="overview-skeleton" aria-busy="true" className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-2 min-[1100px]:grid-cols-4">
      {[0, 1, 2, 3].map((i) => (
        <Card key={i} className="p-[18px]">
          <Skeleton className="h-3.5 w-1/2" />
          <Skeleton className="mt-3 h-7 w-2/3" />
          <Skeleton className="mt-3 h-3 w-1/3" />
        </Card>
      ))}
    </div>
  );
}
