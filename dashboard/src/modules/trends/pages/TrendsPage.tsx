import { useState } from "react";
import { Button, Select, Skeleton } from "../../../components/ui";
import { formatDateTime } from "../../../lib/dates";
import { TrendTable } from "../components/TrendTable";
import { trendsError } from "../errors";
import { useCities, useTrends } from "../hooks";

/** Tendances : classement des produits et des commerces d'une ville (dernier calcul), lecture seule. */
export function TrendsPage() {
  const cities = useCities();
  const [zone, setZone] = useState<number | null>(null);
  const query = useTrends(zone);
  const data = query.data;
  const options = [{ value: "", label: "Choisir une ville" }, ...(cities.data ?? []).map((c) => ({ value: String(c.id), label: c.name }))];

  return (
    <section aria-label="Tendances" className="flex flex-col gap-4 px-8 pb-7 pt-[18px]">
      <h1 className="sr-only">Tendances</h1>
      <div className="flex flex-wrap items-end gap-3">
        <Select label="Ville" value={zone === null ? "" : String(zone)} options={options} disabled={cities.isLoading} onChange={(e) => setZone(e.target.value === "" ? null : Number(e.target.value))} />
        {data?.computed_at && (
          <p className="pb-2 text-[12.5px] text-ink-2">
            Calculé le {formatDateTime(data.computed_at)}
            {data.period_days ? ` · sur ${data.period_days} jours` : ""}
          </p>
        )}
      </div>

      {cities.isError && (
        <div role="alert" className="flex flex-col items-center gap-3 py-8 text-center">
          <p className="text-[13px] text-danger">Impossible de charger la liste des villes.</p>
          <Button variant="secondary" onClick={() => void cities.refetch()}>
            Réessayer
          </Button>
        </div>
      )}
      {zone === null && !cities.isError && (
        <p role="status" className="py-6 text-center text-[13px] text-ink-2">
          Choisissez une ville pour voir ses tendances.
        </p>
      )}
      {zone !== null && query.isLoading && (
        <div role="status" aria-label="Chargement">
          <Skeleton className="h-40 w-full" />
        </div>
      )}
      {zone !== null && query.isError && !data && (
        <div role="alert" className="flex flex-col items-center gap-3 py-8 text-center">
          <p className="text-[13px] text-danger">{trendsError(query.error)}</p>
          <Button variant="secondary" onClick={() => void query.refetch()}>
            Réessayer
          </Button>
        </div>
      )}
      {data && data.computed_at === null && (
        <p role="status" className="py-6 text-center text-[13px] text-ink-2">
          Aucun calcul de tendances pour cette ville pour l'instant.
        </p>
      )}
      {data && data.computed_at !== null && (
        <div className="grid grid-cols-1 gap-4 min-[1100px]:grid-cols-2">
          <div className="flex flex-col gap-2">
            <h2 className="text-[14px] font-bold">Produits les plus recherchés</h2>
            <TrendTable rows={data.products} caption="Produits les plus recherchés" nameHeader="Produit" />
          </div>
          <div className="flex flex-col gap-2">
            <h2 className="text-[14px] font-bold">Commerces les plus contactés</h2>
            <TrendTable rows={data.businesses.map((b) => ({ id: b.id, rank: b.rank, name: b.name, zone: b.zone.name }))} caption="Commerces les plus contactés" nameHeader="Commerce" showZone />
          </div>
        </div>
      )}
    </section>
  );
}
