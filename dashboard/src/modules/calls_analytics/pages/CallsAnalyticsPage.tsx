import { useState } from "react";
import { Button, Card, EmptyState, Skeleton } from "../../../components/ui";
import { formatDate } from "../../../lib/dates";
import { formatInt } from "../../../lib/format";
import { BarList } from "../../search_analytics/components/BarList";
import { PeriodSelect } from "../../search_analytics/components/PeriodSelect";
import { analyticsError } from "../../search_analytics/errors";
import { DEFAULT_DAYS } from "../../search_analytics/types";
import { CallsChart } from "../components/CallsChart";
import { useCallAnalytics } from "../hooks";

/** Appels : par jour, par opérateur (Orange / MTN), par plateforme et par canal. Lecture seule. */
export function CallsAnalyticsPage() {
  const [days, setDays] = useState(DEFAULT_DAYS);
  const query = useCallAnalytics(days);
  const data = query.data;

  return (
    <section aria-label="Appels" className="flex flex-col gap-4 px-8 pb-7 pt-[18px]">
      <h1 className="sr-only">Appels</h1>
      <div className="flex flex-wrap items-end justify-between gap-3">
        <PeriodSelect days={days} onChange={setDays} />
        {data && (
          <p className="text-[12.5px] text-ink-2">
            Depuis le {formatDate(data.since)} · {formatInt(data.total_calls)} appels
          </p>
        )}
      </div>

      {query.isLoading && (
        <div role="status" aria-label="Chargement">
          <Skeleton className="h-40 w-full" />
        </div>
      )}
      {query.isError && !data && (
        <div role="alert" className="flex flex-col items-center gap-3 py-8 text-center">
          <p className="text-[13px] text-danger">{analyticsError(query.error, "les appels")}</p>
          <Button variant="secondary" onClick={() => void query.refetch()}>
            Réessayer
          </Button>
        </div>
      )}
      {data && data.total_calls === 0 && <EmptyState title="Aucun appel sur cette période" description="Choisissez une période plus longue." />}
      {data && data.total_calls > 0 && (
        <>
          <Card>
            <h2 className="mb-3 text-[14px] font-bold">Appels par jour</h2>
            <CallsChart days={data.by_day} />
          </Card>
          <div className="grid grid-cols-1 gap-4 min-[1100px]:grid-cols-3">
            <Card>
              <h2 className="mb-3 text-[14px] font-bold">Par opérateur</h2>
              <BarList
                label="Appels par opérateur"
                items={[
                  { key: "orange", label: "Orange", value: data.by_operator.orange },
                  { key: "mtn", label: "MTN", value: data.by_operator.mtn },
                  { key: "unknown", label: "Inconnu", value: data.by_operator.unknown },
                ]}
              />
            </Card>
            <Card>
              <h2 className="mb-3 text-[14px] font-bold">Par plateforme</h2>
              <BarList
                label="Appels par plateforme"
                items={[
                  { key: "android", label: "Android", value: data.by_platform.android },
                  { key: "ios", label: "iOS", value: data.by_platform.ios },
                ]}
              />
            </Card>
            <Card>
              <h2 className="mb-3 text-[14px] font-bold">Par canal</h2>
              <BarList
                label="Appels par canal"
                items={[
                  { key: "call", label: "Appel", value: data.by_channel.call },
                  { key: "whatsapp", label: "WhatsApp", value: data.by_channel.whatsapp },
                ]}
              />
            </Card>
          </div>
        </>
      )}
    </section>
  );
}
