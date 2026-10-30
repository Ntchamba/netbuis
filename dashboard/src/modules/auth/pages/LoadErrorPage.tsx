import { useAuth } from "../../../auth/useAuth";
import { Button, Card } from "../../../components/ui";

/** Session valide mais /api/admin/me/ en échec (serveur ou réseau) : on ne déconnecte pas en silence. */
export function LoadErrorPage() {
  const { retry, logout } = useAuth();
  return (
    <main className="flex min-h-screen items-center justify-center bg-bg p-6 text-ink">
      <Card className="w-full max-w-[420px] text-center">
        <h1 className="mb-2 text-[18px] font-extrabold">Chargement impossible</h1>
        <p role="alert" className="mb-4 text-[13px] text-ink-2">
          Impossible de récupérer votre profil. Vérifiez votre réseau puis réessayez.
        </p>
        <div className="flex justify-center gap-2">
          <Button onClick={() => void retry()}>Réessayer</Button>
          <Button variant="secondary" onClick={() => void logout()}>
            Se déconnecter
          </Button>
        </div>
      </Card>
    </main>
  );
}
