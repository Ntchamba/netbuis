import { Link } from "react-router-dom";
import { Card } from "../../../components/ui";
import { PATHS, referentialPath } from "../../../routes/paths";
import { ReferentialsNav } from "../components/RowParts";
import { REF_CONFIGS } from "../types";

/** Page d'index : les 7 sections et « À examiner ». */
export function ReferentialsIndexPage() {
  const cards = [
    ...REF_CONFIGS.map((c) => ({ key: c.type, to: referentialPath(c.type), title: c.title, text: c.description })),
    { key: "a-examiner", to: PATHS.referentielsAExaminer, title: "À examiner", text: "Les valeurs libres saisies par les commerçants, à ajouter officiellement ou non." },
  ];
  return (
    <section aria-label="Référentiels" className="flex flex-col gap-4 px-8 pb-7 pt-[18px]">
      <ReferentialsNav />
      <p className="text-[12.5px] text-ink-2">
        Les listes que les commerçants choisissent dans l'application. Rien ne se supprime : un élément se désactive, puis se réactive.
      </p>
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {cards.map((c) => (
          <Link key={c.key} to={c.to} className="no-underline">
            <Card className="h-full hover:border-accent">
              <h3 className="text-[15px] font-extrabold text-ink">{c.title}</h3>
              <p className="mt-1 text-[12.5px] text-ink-2">{c.text}</p>
            </Card>
          </Link>
        ))}
      </div>
    </section>
  );
}
