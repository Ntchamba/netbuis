import { Card, EmptyState } from "../../../components/ui";

/** Bloc réservé : les données arrivent avec V01 (équipe NetBuis). */
export function TeamPerformance() {
  return (
    <Card>
      <h2 className="mb-3.5 text-[14.5px] font-extrabold">Performance équipe NetBuis</h2>
      <EmptyState title="Fonction à venir" />
    </Card>
  );
}
