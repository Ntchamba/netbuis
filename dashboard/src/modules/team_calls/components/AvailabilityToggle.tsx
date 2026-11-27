import { cn } from "../../../lib/cn";
import { useCalls } from "../CallsProvider";

const STATUS_LABEL = { off: "", connecting: "Connexion…", open: "", reconnecting: "Reconnexion…", forbidden: "Droit retiré" } as const;

/** « Disponible / Indisponible » : visible sur toutes les pages pour qui a le droit de répondre. */
export function AvailabilityToggle() {
  const { enabled, available, presenceBusy, status, setAvailable } = useCalls();
  if (!enabled) return null;
  const note = STATUS_LABEL[status];
  return (
    <div className="flex items-center gap-3">
      <span role="status" aria-live="polite" className="text-[12px] text-ink-2">
        {note}
      </span>
      <button
        type="button"
        role="switch"
        aria-checked={available}
        aria-label="Disponible pour les appels"
        disabled={presenceBusy || status === "forbidden"}
        onClick={() => void setAvailable(!available)}
        className={cn(
          "inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-full border px-4 text-[12.5px] font-bold disabled:cursor-not-allowed disabled:opacity-60",
          "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
          available ? "border-success bg-success-bg text-success" : "border-line bg-transparent text-ink-2",
        )}
      >
        <span aria-hidden="true" className={cn("h-2.5 w-2.5 rounded-full", available ? "bg-success" : "bg-ink-3")} />
        {available ? "Disponible" : "Indisponible"}
      </button>
    </div>
  );
}
