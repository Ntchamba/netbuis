import { useState } from "react";
import { Button, Modal } from "../../../components/ui";

const MASK = "••••••••••••";

interface Props {
  name: string;
  password: string;
  onDone: () => void;
}

/**
 * 🔒 Affiche le mot de passe temporaire UNE SEULE FOIS. Il vient uniquement de `mutation.data` (propriété),
 * n'est ni stocké, ni mis dans l'adresse, un toast, la console ou le titre. Seul le bouton ferme la fenêtre
 * (Échap et clic sur le fond sont ignorés pour éviter de le perdre par mégarde).
 */
export function TemporaryPasswordDialog({ name, password, onDone }: Props) {
  const [shown, setShown] = useState(false);
  const [copyMessage, setCopyMessage] = useState<string | null>(null);

  const copy = async () => {
    try {
      if (!navigator.clipboard?.writeText) throw new Error("indisponible");
      await navigator.clipboard.writeText(password);
      setCopyMessage("Mot de passe copié.");
    } catch {
      // Repli : on l'affiche pour que la personne le sélectionne et le copie à la main.
      setShown(true);
      setCopyMessage("Copie automatique impossible : sélectionnez le mot de passe affiché et copiez-le à la main.");
    }
  };

  return (
    <Modal
      open
      title="Mot de passe temporaire"
      onClose={() => undefined}
      footer={
        <Button onClick={onDone}>J'ai noté le mot de passe</Button>
      }
    >
      <p role="alert" className="rounded-[10px] bg-warn-bg px-3 py-2 text-[13px] font-bold text-warn">
        Notez-le maintenant, il ne sera plus affiché.
      </p>
      <p className="text-[13px] text-ink-2">
        Compte créé pour {name}. Transmettez ce mot de passe par un canal sûr. Il reste valable jusqu'à son changement : aucun changement de mot de passe n'est possible pour
        l'instant.
      </p>
      <div className="flex items-center gap-2">
        <code
          data-testid="temporary-password"
          aria-label="Mot de passe temporaire"
          className="min-w-0 flex-1 select-all break-all rounded-[10px] border border-line bg-bg px-3 py-2 text-[14px]"
        >
          {shown ? password : MASK}
        </code>
        <Button variant="secondary" aria-pressed={shown} onClick={() => setShown((v) => !v)}>
          {shown ? "Masquer" : "Afficher"}
        </Button>
        <Button variant="secondary" onClick={() => void copy()}>
          Copier
        </Button>
      </div>
      {copyMessage && (
        <p role="status" className="text-[12px] text-ink-2">
          {copyMessage}
        </p>
      )}
    </Modal>
  );
}
