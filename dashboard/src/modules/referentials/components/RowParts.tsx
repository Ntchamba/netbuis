import { NavLink } from "react-router-dom";
import { Can } from "../../../auth/permissions";
import { Badge, Button } from "../../../components/ui";
import { cn } from "../../../lib/cn";
import { PATHS, referentialPath } from "../../../routes/paths";
import { REF_CONFIGS, type ActiveAction, type RefRow } from "../types";
import { PERMISSION } from "./ActiveToggle";

export function StatusBadge({ active }: { active: boolean }) {
  return active ? <Badge status="actif" /> : <Badge status="bloque">Désactivé</Badge>;
}

interface RowActionsProps {
  row: RefRow;
  busy: boolean;
  onEdit: () => void;
  onToggle: (action: ActiveAction) => void;
  children?: React.ReactNode;
}

/** Modifier · Désactiver / Réactiver. Pas de « Supprimer » : les suppressions sont des désactivations. */
export function RowActions({ row, busy, onEdit, onToggle, children }: RowActionsProps) {
  const small = "px-2.5 py-1.5 text-[11.5px]";
  return (
    <Can permission={PERMISSION}>
      <div className="flex flex-wrap justify-end gap-2">
        {children}
        <Button variant="secondary" className={small} disabled={busy} onClick={onEdit}>
          Modifier
        </Button>
        {row.is_active ? (
          <Button variant="danger" className={small} disabled={busy} onClick={() => onToggle("deactivate")}>
            Désactiver
          </Button>
        ) : (
          <Button variant="secondary" className={small} disabled={busy} onClick={() => onToggle("reactivate")}>
            Réactiver
          </Button>
        )}
      </div>
    </Can>
  );
}

/** Navigation interne du module : les 7 sections et « À examiner ». */
export function ReferentialsNav() {
  const link = ({ isActive }: { isActive: boolean }) =>
    cn(
      "whitespace-nowrap rounded-full border px-[15px] py-2 text-[12.5px] font-bold",
      isActive ? "border-accent bg-accent text-on-accent" : "border-line bg-transparent text-ink-2",
    );
  return (
    <nav aria-label="Sections des référentiels" className="flex flex-wrap gap-2">
      <NavLink to={PATHS.referentiels} end className={link}>
        Vue d'ensemble
      </NavLink>
      {REF_CONFIGS.map((c) => (
        <NavLink key={c.type} to={referentialPath(c.type)} className={link}>
          {c.title}
        </NavLink>
      ))}
      <NavLink to={PATHS.referentielsAExaminer} className={link}>
        À examiner
      </NavLink>
    </nav>
  );
}
