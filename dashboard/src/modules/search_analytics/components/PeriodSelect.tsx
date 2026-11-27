import { Select } from "../../../components/ui";
import { PERIOD_OPTIONS } from "../types";

export function PeriodSelect({ days, onChange }: { days: number; onChange: (days: number) => void }) {
  return <Select label="Période" value={String(days)} options={[...PERIOD_OPTIONS]} onChange={(e) => onChange(Number(e.target.value))} />;
}
