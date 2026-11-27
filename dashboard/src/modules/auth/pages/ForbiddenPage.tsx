import { useAuth } from "../../../auth/useAuth";
import { Button, Card } from "../../../components/ui";

/** Admin connecté mais sans groupe (403 sur /api/admin/me/). */
export function ForbiddenPage() {
  const { logout } = useAuth();
  return (
    <main className="flex min-h-screen items-center justify-center bg-bg p-6 text-ink">
      <Card className="w-full max-w-[420px] text-center">
        <h1 className="mb-2 text-[18px] font-extrabold">Accès non autorisé</h1>
        <p className="mb-4 text-[13px] text-ink-2">
          Votre compte n'a aucun rôle d'administration. Contactez un Administrateur complet.
        </p>
        <Button onClick={() => void logout()}>Se déconnecter</Button>
      </Card>
    </main>
  );
}
