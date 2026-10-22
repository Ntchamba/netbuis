import { useParams } from "react-router-dom";
import { ReferentialsNav } from "../components/RowParts";
import { configFor } from "../types";
import { ReferentialListPage } from "./ReferentialListPage";

/** Choisit la section selon l'adresse ; un type inconnu affiche un message, sans requête. */
export function ReferentialTypePage() {
  const { type } = useParams();
  const config = configFor(type);
  if (!config) {
    return (
      <section className="flex flex-col gap-4 px-8 pb-7 pt-[18px]">
        <ReferentialsNav />
        <p role="alert" className="text-[13px] text-danger">
          Cette section n'existe pas.
        </p>
      </section>
    );
  }
  // `key` : changer de section repart d'un état neuf (page, filtres, recherche).
  return <ReferentialListPage key={config.type} config={config} />;
}
