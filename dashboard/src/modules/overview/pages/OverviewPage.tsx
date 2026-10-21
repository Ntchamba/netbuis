import { Button } from "../../../components/ui";
import { HighTrafficCard } from "../components/HighTrafficCard";
import { KpiGrid, KpiGridSkeleton } from "../components/KpiGrid";
import { RecentRequests } from "../components/RecentRequests";
import { SubscriptionsCard } from "../components/SubscriptionsCard";
import { TeamPerformance } from "../components/TeamPerformance";
import { useAdminStats, useRecentRequests } from "../hooks";
import { usePermissions } from "../../../auth/permissions";

export function OverviewPage() {
  const { can } = usePermissions();
  const stats = useAdminStats();
  const recent = useRecentRequests();

  return (
    <section aria-label="Vue d'ensemble" className="px-5 py-7 min-[900px]:px-8">
      {/* Le titre visible est dans l'en-tête de la page (maquette) ; ce h1 est le titre du document. */}
      <h1 className="sr-only">Vue d'ensemble</h1>
      {stats.isPending && (
        <div role="status" aria-label="Chargement">
          <KpiGridSkeleton />
        </div>
      )}
      {stats.isError && (
        <div role="alert" className="flex flex-col items-center gap-3 rounded-2xl border border-line bg-card px-6 py-10 text-center">
          <p className="text-[14px] font-bold">Impossible de charger les chiffres.</p>
          <p className="text-[12.5px] text-ink-2">Vérifiez votre connexion puis réessayez.</p>
          <Button onClick={() => void stats.refetch()} loading={stats.isFetching}>
            Réessayer
          </Button>
        </div>
      )}
      {stats.data && (
        <>
          <KpiGrid stats={stats.data} />
          <div className="mb-6 grid grid-cols-1 gap-4 min-[1100px]:grid-cols-[1.3fr_1fr]">
            {can("peut_voir_demandes") ? (
              <RecentRequests
                loading={recent.isPending}
                error={recent.isError}
                requests={recent.data}
                onRetry={() => void recent.refetch()}
              />
            ) : (
              <div />
            )}
            <TeamPerformance />
          </div>
          <div className="grid grid-cols-1 gap-4 min-[1100px]:grid-cols-2">
            <SubscriptionsCard stats={stats.data} />
            <HighTrafficCard stats={stats.data} />
          </div>
        </>
      )}
    </section>
  );
}
