import { useNavigate } from "react-router-dom";
import { Can } from "../../../auth/permissions";
import { Button, Table, type Column } from "../../../components/ui";
import { referentialPath } from "../../../routes/paths";
import { PERMISSION } from "../components/ActiveToggle";
import { ReferentialsNav } from "../components/RowParts";
import { useFreeValues } from "../hooks";
import type { FreeValue, FreeValues, RefType } from "../types";

const SECTIONS: Array<{ key: keyof FreeValues; title: string; type: RefType }> = [
  { key: "secteur_libre", title: "Secteurs saisis librement", type: "sectors" },
  { key: "categorie_service_libre", title: "Catégories de service saisies librement", type: "service-categories" },
  { key: "structure_type_libre", title: "Types de structure « Autre »", type: "structure-types" },
];

/** « À examiner » : valeurs libres des commerçants et leur fréquence, pour décider de les rendre officielles. */
export function FreeValuesPage() {
  const query = useFreeValues();
  const navigate = useNavigate();
  const data = query.data;

  const columns = (type: RefType): Column<FreeValue>[] => [
    { key: "value", header: "Valeur saisie", render: (r) => r.value },
    { key: "count", header: "Commerces", render: (r) => r.count },
    {
      key: "actions",
      header: "Actions",
      align: "right",
      render: (r) => (
        <Can permission={PERMISSION}>
          <Button
            variant="secondary"
            className="px-2.5 py-1.5 text-[11.5px]"
            aria-label={`Ajouter « ${r.value} » comme officiel`}
            onClick={() => navigate(referentialPath(type), { state: { prefill: { name: r.value } } })}
          >
            Ajouter comme officiel
          </Button>
        </Can>
      ),
    },
  ];

  return (
    <section aria-label="À examiner" className="flex flex-col gap-4 px-8 pb-7 pt-[18px]">
      <ReferentialsNav />
      <p className="text-[12.5px] text-ink-2">
        Ce que les commerçants ont écrit eux-mêmes en choisissant « Autre », du plus fréquent au moins fréquent.
      </p>
      {query.isError && !data ? (
        <div role="alert" className="flex flex-col items-center gap-3 py-8 text-center">
          <p className="text-[13px] text-danger">Impossible de charger les valeurs à examiner.</p>
          <Button variant="secondary" onClick={() => void query.refetch()}>
            Réessayer
          </Button>
        </div>
      ) : (
        SECTIONS.map((s) => (
          <div key={s.key} className="flex flex-col gap-2">
            <h3 className="text-[14px] font-extrabold">{s.title}</h3>
            <Table<FreeValue>
              caption={s.title}
              columns={columns(s.type)}
              rows={data?.[s.key] ?? []}
              rowKey={(r) => r.normalized}
              loading={query.isLoading}
              emptyTitle="Aucune valeur à examiner"
              emptyDescription="Les commerçants n'ont rien saisi ici pour le moment."
            />
          </div>
        ))
      )}
    </section>
  );
}
