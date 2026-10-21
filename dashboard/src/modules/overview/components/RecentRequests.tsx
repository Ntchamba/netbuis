import { Link } from "react-router-dom";
import { Badge, Button, Card, EmptyState, Skeleton } from "../../../components/ui";
import { formatRelative } from "../../../lib/dates";
import { PATHS } from "../../../routes/paths";
import type { RecentRequest } from "../types";

interface Props {
  loading: boolean;
  error: boolean;
  requests: RecentRequest[] | undefined;
  onRetry: () => void;
}

export function RecentRequests({ loading, error, requests, onRetry }: Props) {
  return (
    <Card>
      <div className="mb-3.5 flex items-center justify-between">
        <h2 className="text-[14.5px] font-extrabold">Demandes récentes</h2>
        <Link to={PATHS.demandes} className="rounded text-[12.5px] font-bold text-accent-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent">
          Voir tout →
        </Link>
      </div>
      {loading && (
        <div className="flex flex-col gap-2.5" aria-busy="true">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} className="h-[54px] w-full rounded-[10px]" />
          ))}
        </div>
      )}
      {!loading && error && (
        <div role="alert" className="flex flex-col items-center gap-3 py-6 text-center">
          <p className="text-[13px] text-danger">Impossible de charger les demandes.</p>
          <Button variant="secondary" onClick={onRetry}>
            Réessayer
          </Button>
        </div>
      )}
      {!loading && !error && requests && requests.length === 0 && <EmptyState title="Aucune demande en attente" />}
      {!loading && !error && requests && requests.length > 0 && (
        <ul className="m-0 flex list-none flex-col gap-2.5 p-0">
          {requests.map((r) => (
            <li key={r.id} className="flex items-center justify-between rounded-[10px] bg-bg px-3 py-2.5">
              <div className="min-w-0">
                <div className="truncate text-[13.5px] font-bold">{r.name}</div>
                <div className="mt-0.5 text-[11.5px] text-ink-2">
                  Compte business{r.zone_name ? ` · ${r.zone_name}` : ""} · {formatRelative(r.created_at)}
                </div>
              </div>
              <Badge status="en_attente" />
            </li>
          ))}
        </ul>
      )}
    </Card>
  );
}
