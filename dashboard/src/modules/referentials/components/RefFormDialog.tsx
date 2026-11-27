import { useId, useRef, useState, type FormEvent } from "react";
import { Button, Input, Modal, Select, useToast } from "../../../components/ui";
import { referentialError } from "../errors";
import { useCreateReferential, useRefreshReferentials, useUpdateReferential } from "../hooks";
import { configFor, rowName, ZONE_LEVEL_LABEL, type AdminProduct, type AdminZone, type RefRow, type RefType, type ZoneLevel } from "../types";
import { FIELDS, nameFieldOf, suggestCode, type FieldDef } from "./fields";
import { RefPicker, type PickerValue } from "./RefPicker";

export interface ZoneContext {
  parent: { id: number; name: string } | null;
  levels: ZoneLevel[];
}

interface Props {
  type: RefType;
  /** Présent : modification (niveau, code, secteur et produit ne se modifient pas). */
  row?: RefRow;
  /** Création pré-remplie (par exemple depuis « À examiner »). */
  initial?: { name?: string };
  zone?: ZoneContext;
  onClose: () => void;
}

type Values = Record<string, string>;
type Pickers = Record<string, PickerValue | null>;

function initialValues(type: RefType, row: RefRow | undefined, initial: Props["initial"], zone: ZoneContext | undefined): { values: Values; pickers: Pickers } {
  const values: Values = {};
  const pickers: Pickers = {};
  for (const f of FIELDS[type]) {
    if (f.kind === "picker") {
      pickers[f.name] = null;
      if (row && f.name === "category") {
        const p = row as AdminProduct;
        pickers[f.name] = p.category !== null ? { id: p.category, label: p.category_name ?? `n° ${p.category}` } : null;
      }
      continue;
    }
    const raw = row ? (row as unknown as Record<string, unknown>)[f.name] : undefined;
    values[f.name] = raw === undefined || raw === null ? "" : String(raw);
  }
  if (!row) {
    if (type === "zones") values.level = zone?.levels[0] ?? "";
    const prefill = initial?.name?.trim();
    if (prefill) {
      values[nameFieldOf(type)] = prefill;
      if ("code" in values) values.code = suggestCode(prefill);
    }
  }
  return { values, pickers };
}

function validateField(f: FieldDef, value: string): string | undefined {
  const v = value.trim();
  if (v === "") return f.required ? `${f.label} : champ obligatoire.` : undefined;
  if (f.kind === "text") {
    if (f.max !== undefined && v.length > f.max) return `${f.label} : ${f.max} caractères au plus.`;
    if (f.pattern && !f.pattern.test(v)) return f.patternMessage ?? `${f.label} : format incorrect.`;
  }
  if (f.kind === "integer") {
    if (!/^\d+$/.test(v)) return `${f.label} : entrez un nombre entier positif ou nul.`;
  }
  if (f.kind === "decimal") {
    const n = Number(v.replace(",", "."));
    if (!Number.isFinite(n)) return `${f.label} : entrez un nombre.`;
    if (f.min !== undefined && n < f.min) return `${f.label} : ${f.min} au moins.`;
    if (f.maxValue !== undefined && n > f.maxValue) return `${f.label} : ${f.maxValue} au plus.`;
  }
  return undefined;
}

/** Formulaire d'ajout ou de modification, validé côté client puis par le serveur. Sans double envoi. */
export function RefFormDialog({ type, row, initial, zone, onClose }: Props) {
  const formId = useId();
  const toast = useToast();
  const editing = row !== undefined;
  const create = useCreateReferential(type);
  const update = useUpdateReferential(type);
  const refresh = useRefreshReferentials();
  const start = useRef(initialValues(type, row, initial, zone)).current;
  const [values, setValues] = useState<Values>(start.values);
  const [pickers, setPickers] = useState<Pickers>(start.pickers);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState("");
  const lock = useRef(false);
  const [sending, setSending] = useState(false);

  const config = configFor(type)!;
  const fields = FIELDS[type].filter((f) => !(editing && f.createOnly));
  const fixed = FIELDS[type].filter((f) => editing && f.createOnly);

  const setValue = (name: string, value: string) => {
    setValues((cur) => ({ ...cur, [name]: value }));
    setErrors((cur) => (cur[name] ? { ...cur, [name]: "" } : cur));
  };

  const buildPayload = (): Record<string, unknown> => {
    const payload: Record<string, unknown> = {};
    for (const f of fields) {
      if (f.kind === "picker") {
        const picked = pickers[f.name] ?? null;
        if (editing) {
          const before = f.name === "category" ? (row as AdminProduct).category : null;
          if ((picked?.id ?? null) !== before) payload[f.name] = picked?.id ?? null;
        } else if (picked) payload[f.name] = picked.id;
        continue;
      }
      const v = (values[f.name] ?? "").trim();
      const before = row ? String((row as unknown as Record<string, unknown>)[f.name] ?? "") : "";
      if (editing && v === before) continue;
      if (f.kind === "integer") {
        if (v !== "") payload[f.name] = Number(v);
      } else if (f.kind === "decimal") {
        if (v !== "") payload[f.name] = Number(v.replace(",", "."));
        else if (editing) payload[f.name] = null;
      } else if (v !== "" || editing) payload[f.name] = v;
    }
    if (!editing && type === "zones" && zone?.parent) payload.parent = zone.parent.id;
    return payload;
  };

  const onSubmit = (event: FormEvent) => {
    event.preventDefault();
    if (lock.current) return;
    const found: Record<string, string> = {};
    for (const f of fields) {
      if (f.kind === "picker") {
        if (f.required && !pickers[f.name]) found[f.name] = `${f.label} : choisissez une valeur.`;
        continue;
      }
      const message = validateField(f, values[f.name] ?? "");
      if (message) found[f.name] = message;
    }
    setErrors(found);
    setFormError("");
    if (Object.keys(found).length > 0) return;

    const payload = buildPayload();
    if (editing && Object.keys(payload).length === 0) {
      onClose();
      return;
    }
    lock.current = true;
    setSending(true);
    const options = {
      onSettled: () => {
        lock.current = false;
        setSending(false);
      },
      onSuccess: () => {
        toast.success(editing ? "Modification enregistrée" : "Élément ajouté");
        onClose();
      },
      onError: (err: unknown) => {
        const e = referentialError(err, nameFieldOf(type));
        if (e.refresh) {
          toast.error(e.message);
          onClose();
          void refresh();
          return;
        }
        const next: Record<string, string> = {};
        const rest: string[] = [];
        const known = new Set(fields.map((f) => f.name));
        for (const [key, message] of Object.entries(e.fields ?? {})) {
          if (known.has(key)) next[key] = message;
          else rest.push(message);
        }
        if (e.field && known.has(e.field)) next[e.field] = e.message;
        let general: string[];
        if (e.field && known.has(e.field)) {
          next[e.field] = e.message;
          general = rest;
        } else if (Object.keys(next).length > 0) general = rest;
        else general = [e.message, ...rest];
        setErrors(next);
        setFormError(general.join(" "));
      },
    };
    if (editing) update.mutate({ id: row.id, payload }, options);
    else create.mutate(payload, options);
  };

  const title = editing ? `Modifier « ${rowName(row)} »` : `Ajouter ${config.singular}`;
  return (
    <Modal
      open
      title={title}
      onClose={() => {
        if (!sending) onClose();
      }}
      footer={
        <>
          <Button variant="secondary" disabled={sending} onClick={onClose}>
            Annuler
          </Button>
          <Button type="submit" form={formId} loading={sending}>
            {editing ? "Enregistrer" : "Ajouter"}
          </Button>
        </>
      }
    >
      <form id={formId} onSubmit={onSubmit} noValidate className="flex flex-col gap-3">
        {fixed.length > 0 && (
          <dl className="flex flex-col gap-1 text-[12.5px] text-ink-2">
            {fixed.map((f) => (
              <div key={f.name} className="flex gap-2">
                <dt className="font-bold">{f.label} :</dt>
                <dd data-testid={`fixe-${f.name}`}>{fixedText(type, f, row)}</dd>
              </div>
            ))}
          </dl>
        )}
        {!editing && type === "zones" && (
          <p className="text-[12.5px] text-ink-2" data-testid="zone-parent">
            Rattachée à : {zone?.parent ? zone.parent.name : "aucune zone (niveau le plus haut)"}
          </p>
        )}
        {fields.map((f) => {
          if (f.kind === "picker") {
            return (
              <RefPicker
                key={f.name}
                label={f.label}
                picker={f.picker!}
                value={pickers[f.name] ?? null}
                onChange={(v) => {
                  setPickers((cur) => ({ ...cur, [f.name]: v }));
                  setErrors((cur) => ({ ...cur, [f.name]: "" }));
                }}
                emptyLabel={f.required ? "Choisir…" : "Aucune"}
                error={errors[f.name] || undefined}
              />
            );
          }
          if (f.kind === "level") {
            return (
              <Select
                key={f.name}
                label={f.label}
                value={values[f.name] ?? ""}
                onChange={(e) => setValue(f.name, e.target.value)}
                options={(zone?.levels ?? []).map((l) => ({ value: l, label: ZONE_LEVEL_LABEL[l] }))}
                error={errors[f.name] || undefined}
              />
            );
          }
          return (
            <div key={f.name} className="flex flex-col gap-1">
              <Input
                label={f.label}
                value={values[f.name] ?? ""}
                onChange={(e) => setValue(f.name, e.target.value)}
                inputMode={f.kind === "integer" ? "numeric" : f.kind === "decimal" ? "decimal" : undefined}
                autoComplete="off"
                error={errors[f.name] || undefined}
              />
              {f.help && <p className="text-[11.5px] text-ink-3">{f.help}</p>}
            </div>
          );
        })}
        {formError && (
          <p role="alert" data-testid="form-error" className="text-[12.5px] text-danger">
            {formError}
          </p>
        )}
      </form>
    </Modal>
  );
}

function fixedText(type: RefType, f: FieldDef, row: RefRow | undefined): string {
  if (!row) return "";
  if (f.name === "level") return ZONE_LEVEL_LABEL[(row as AdminZone).level];
  if (f.name === "product" && "product_name" in row) return row.product_name;
  if (f.name === "sector" && "sector" in row) return `n° ${String(row.sector)}`;
  if (type === "zones") return "";
  return String((row as unknown as Record<string, unknown>)[f.name] ?? "");
}
