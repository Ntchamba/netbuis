import { useRef, useState } from "react";
import { Button, Card, ConfirmDialog, Input, Skeleton, useToast } from "../../../components/ui";
import { formatInt } from "../../../lib/format";
import { useSettings, useUpdateSetting } from "../hooks";
import type { Setting } from "../types";
import { parseSettingValue, settingError } from "../validation";

interface Pending {
  setting: Setting;
  value: number;
}

/** Réglages de la plateforme : une valeur entière par clé, bornes du serveur, confirmation avant envoi. */
export function SettingsPage() {
  const query = useSettings();
  const mutation = useUpdateSetting();
  const toast = useToast();
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [pending, setPending] = useState<Pending | null>(null);
  const [sending, setSending] = useState(false);
  const lock = useRef(false);
  const busy = sending || mutation.isPending;

  const setError = (key: string, message: string | null) =>
    setErrors((cur) => {
      const next = { ...cur };
      if (message === null) delete next[key];
      else next[key] = message;
      return next;
    });

  const onSave = (s: Setting) => {
    const parsed = parseSettingValue(drafts[s.key] ?? String(s.value), s.min, s.max);
    if ("error" in parsed) {
      setError(s.key, parsed.error);
      return;
    }
    if (parsed.value === s.value) {
      setError(s.key, "Cette valeur est déjà celle en vigueur.");
      return;
    }
    setError(s.key, null);
    setPending({ setting: s, value: parsed.value });
  };

  const onConfirm = () => {
    if (!pending || lock.current) return;
    const { setting, value } = pending;
    lock.current = true;
    setSending(true);
    mutation.mutate(
      { key: setting.key, value },
      {
        onSettled: () => {
          lock.current = false;
          setSending(false);
        },
        onSuccess: () => {
          setPending(null);
          setDrafts((cur) => {
            const next = { ...cur };
            delete next[setting.key];
            return next;
          });
          toast.success("Réglage enregistré");
        },
        onError: (err) => {
          const e = settingError(err);
          setPending(null);
          setError(setting.key, e.message);
          toast.error(e.message);
        },
      },
    );
  };

  return (
    <section aria-label="Réglages" className="flex flex-col gap-4 px-8 pb-7 pt-[18px]">
      <p className="text-[13px] text-ink-2">
        Valeurs entières, dans les bornes indiquées. Chaque modification est enregistrée dans le journal d'audit.
      </p>
      {query.isLoading && <Skeleton className="h-24 w-full" />}
      {query.isError && !query.data && (
        <div role="alert" className="flex flex-col items-center gap-3 py-8 text-center">
          <p className="text-[13px] text-danger">Impossible de charger les réglages.</p>
          <Button variant="secondary" onClick={() => void query.refetch()}>
            Réessayer
          </Button>
        </div>
      )}
      <div className="flex flex-col gap-3">
        {query.data?.map((s) => (
          <Card key={s.key}>
            <div data-testid={`setting-${s.key}`} className="flex flex-wrap items-end justify-between gap-4">
              <div className="min-w-0 flex-1">
                <div className="text-[14px] font-bold">{s.label}</div>
                <div className="mt-1 text-[12px] text-ink-2">
                  Valeur actuelle : <strong data-testid={`setting-value-${s.key}`}>{formatInt(s.value)}</strong> · par défaut {formatInt(s.default)} · de {formatInt(s.min)} à{" "}
                  {formatInt(s.max)}
                </div>
              </div>
              <form
                className="flex items-end gap-2"
                onSubmit={(e) => {
                  e.preventDefault();
                  onSave(s);
                }}
                noValidate
              >
                <Input
                  label="Nouvelle valeur"
                  inputMode="numeric"
                  autoComplete="off"
                  value={drafts[s.key] ?? String(s.value)}
                  error={errors[s.key]}
                  disabled={busy}
                  onChange={(e) => {
                    setDrafts((cur) => ({ ...cur, [s.key]: e.target.value }));
                    setError(s.key, null);
                  }}
                  className="w-36"
                />
                <Button type="submit" disabled={busy}>
                  Enregistrer
                </Button>
              </form>
            </div>
          </Card>
        ))}
      </div>
      <ConfirmDialog
        open={pending !== null}
        title="Modifier le réglage"
        message={
          pending
            ? `${pending.setting.label} : ${formatInt(pending.setting.value)} → ${formatInt(pending.value)}. Le changement s'applique à toute la plateforme.`
            : undefined
        }
        confirmLabel="Enregistrer"
        variant="primary"
        loading={busy}
        onConfirm={onConfirm}
        onCancel={() => {
          if (!busy) setPending(null);
        }}
      />
    </section>
  );
}
