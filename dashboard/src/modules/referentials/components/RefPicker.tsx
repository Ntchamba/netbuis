import { useEffect, useId, useState } from "react";
import { useReferentials } from "../hooks";
import type { AdminItem, AdminProduct } from "../types";
import type { PickerType } from "./fields";

export interface PickerValue {
  id: number;
  label: string;
}

interface Props {
  label: string;
  picker: PickerType;
  value: PickerValue | null;
  onChange: (value: PickerValue | null) => void;
  emptyLabel?: string;
  error?: string;
  /** Champ non modifiable. */
  disabled?: boolean;
  /** Liste les éléments actifs seulement (formulaires) ou tous (filtres). */
  onlyActive?: boolean;
}

const DELAY_MS = 300;

/** Choix d'un élément d'un autre référentiel : un champ de recherche et une liste (50 au plus à la fois). */
export function RefPicker({ label, picker, value, onChange, emptyLabel = "Aucun", error, disabled, onlyActive = true }: Props) {
  const id = useId();
  const [text, setText] = useState("");
  const [q, setQ] = useState("");
  useEffect(() => {
    const next = text.trim();
    if (next === q) return;
    const t = setTimeout(() => setQ(next), DELAY_MS);
    return () => clearTimeout(t);
  }, [text, q]);

  const query = useReferentials(picker, { page: 1, pageSize: 50, q, status: onlyActive ? "active" : "all" });
  const rows = (query.data?.results ?? []) as Array<AdminItem | AdminProduct>;
  const options: PickerValue[] = rows.map((r) => ({ id: r.id, label: r.name }));
  if (value && !options.some((o) => o.id === value.id)) options.unshift(value);

  return (
    <div className="flex flex-col gap-1">
      <label htmlFor={`${id}-select`} className="text-[12px] font-bold text-ink-2">
        {label}
      </label>
      <input
        type="search"
        aria-label={`Rechercher (${label})`}
        placeholder="Rechercher…"
        value={text}
        disabled={disabled}
        onChange={(e) => setText(e.target.value)}
        autoComplete="off"
        className="w-full rounded-[10px] border border-line bg-card px-3 py-1.5 text-[12.5px] text-ink placeholder:text-ink-2 disabled:opacity-50"
      />
      <select
        id={`${id}-select`}
        value={value ? String(value.id) : ""}
        disabled={disabled}
        aria-invalid={error ? true : undefined}
        aria-describedby={error ? `${id}-erreur` : undefined}
        onChange={(e) => {
          const picked = options.find((o) => String(o.id) === e.target.value) ?? null;
          onChange(picked);
        }}
        className={`w-full rounded-[10px] border bg-card px-3 py-2 text-[13px] text-ink disabled:opacity-50 ${error ? "border-danger" : "border-line"}`}
      >
        <option value="">{emptyLabel}</option>
        {options.map((o) => (
          <option key={o.id} value={o.id}>
            {o.label}
          </option>
        ))}
      </select>
      {query.isError && (
        <p role="alert" className="text-[11.5px] text-danger">
          Impossible de charger la liste.{" "}
          <button type="button" className="cursor-pointer underline" onClick={() => void query.refetch()}>
            Réessayer
          </button>
        </p>
      )}
      {error && (
        <p id={`${id}-erreur`} role="alert" className="text-[11.5px] text-danger">
          {error}
        </p>
      )}
    </div>
  );
}
