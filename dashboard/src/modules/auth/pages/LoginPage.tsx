import { useRef, useState, type FormEvent } from "react";
import { Navigate, useLocation } from "react-router-dom";
import { useAuth } from "../../../auth/useAuth";
import { Button, Card, Input } from "../../../components/ui";
import { normalizeCameroonPhone } from "../../../lib/format";
import { loginErrorMessage } from "../errors";

export const MSG_PHONE_INVALID = "Numéro invalide. Format : +237 6XXXXXXXX.";
export const MSG_PASSWORD_REQUIRED = "Saisissez votre mot de passe.";

export function LoginPage() {
  const { status, login } = useAuth();
  const location = useLocation();
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [phoneError, setPhoneError] = useState<string>();
  const [passwordError, setPasswordError] = useState<string>();
  const [formError, setFormError] = useState<string>();
  const [sending, setSending] = useState(false);
  const inFlight = useRef(false);

  if (status === "authenticated" || status === "forbidden") {
    const from = (location.state as { from?: string } | null)?.from ?? "/";
    return <Navigate to={from} replace />;
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (inFlight.current) return; // anti double soumission
    const normalized = normalizeCameroonPhone(phone);
    setFormError(undefined);
    setPhoneError(normalized ? undefined : MSG_PHONE_INVALID);
    setPasswordError(password ? undefined : MSG_PASSWORD_REQUIRED);
    if (!normalized || !password) return;

    inFlight.current = true;
    setSending(true);
    try {
      await login(normalized, password);
    } catch (err) {
      setPassword(""); // le mot de passe n'est pas conservé après un échec
      setFormError(loginErrorMessage(err));
    } finally {
      inFlight.current = false;
      setSending(false);
    }
  }

  return (
    <Card>
      <h1 className="mb-4 text-[18px] font-extrabold">Connexion</h1>
      <form onSubmit={onSubmit} noValidate className="flex flex-col gap-4">
        <Input
          label="Téléphone"
          type="tel"
          inputMode="tel"
          autoComplete="username"
          placeholder="+237 6XX XX XX XX"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          error={phoneError}
        />
        <Input
          label="Mot de passe"
          type="password"
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          error={passwordError}
        />
        {formError && (
          <p role="alert" className="rounded-[10px] bg-danger-bg px-3 py-2 text-[12.5px] font-bold text-danger">
            {formError}
          </p>
        )}
        <Button type="submit" loading={sending}>
          Se connecter
        </Button>
      </form>
    </Card>
  );
}
