import { act } from "react";
import { afterEach, expect, test, vi } from "vitest";
import { Badge } from "../../src/components/ui/Badge";
import { Button } from "../../src/components/ui/Button";
import { ConfirmDialog } from "../../src/components/ui/ConfirmDialog";
import { Input } from "../../src/components/ui/Input";
import { Pagination } from "../../src/components/ui/Pagination";
import { Table } from "../../src/components/ui/Table";
import { ToastProvider, useToast } from "../../src/components/ui/Toast";
import { byText, cleanup, click, render, type } from "./helpers";

afterEach(async () => {
  await cleanup();
  vi.useRealTimers();
});

test("Button : désactivé pendant le chargement et sans clic", async () => {
  const onClick = vi.fn();
  const div = await render(
    <Button loading onClick={onClick}>
      Valider
    </Button>,
  );
  const b = div.querySelector("button")!;
  expect(b.disabled).toBe(true);
  expect(b.getAttribute("aria-busy")).toBe("true");
  await click(b);
  expect(onClick).not.toHaveBeenCalled();
});

test("Button : le clic fonctionne quand il est actif", async () => {
  const onClick = vi.fn();
  const div = await render(<Button onClick={onClick}>Valider</Button>);
  await click(div.querySelector("button"));
  expect(onClick).toHaveBeenCalledOnce();
});

test("Input : libellé relié au champ et erreur annoncée", async () => {
  const div = await render(<Input label="Téléphone" error="Numéro invalide" />);
  const input = div.querySelector("input")!;
  expect(div.querySelector(`label[for="${input.id}"]`)?.textContent).toBe("Téléphone");
  expect(input.getAttribute("aria-invalid")).toBe("true");
  expect(div.querySelector('[role="alert"]')?.textContent).toBe("Numéro invalide");
});

test("Input : sans erreur, pas d'alerte", async () => {
  const div = await render(<Input label="Nom" />);
  expect(div.querySelector('[role="alert"]')).toBeNull();
  expect(div.querySelector("input")!.getAttribute("aria-invalid")).toBeNull();
});

test("Badge : libellés de statut", async () => {
  const div = await render(
    <>
      <Badge status="actif" />
      <Badge status="en_attente" />
      <Badge status="rejete" />
      <Badge status="bloque" />
      <Badge status="abonne" />
    </>,
  );
  expect(Array.from(div.querySelectorAll("span")).map((s) => s.textContent)).toEqual([
    "Actif",
    "En attente",
    "Rejeté",
    "Bloqué",
    "Abonné",
  ]);
});

const cols = [
  { key: "n", header: "Nom", render: (r: { n: string }) => r.n },
  { key: "t", header: "Type", render: () => "Business" },
];

test("Table : lignes affichées", async () => {
  const div = await render(<Table columns={cols} rows={[{ n: "Mama" }, { n: "Jeff" }]} rowKey={(r) => r.n} />);
  expect(div.querySelectorAll("tbody tr")).toHaveLength(2);
  expect(div.querySelectorAll("th")).toHaveLength(2);
});

test("Table : état vide et état chargement", async () => {
  const vide = await render(<Table columns={cols} rows={[]} rowKey={(r: { n: string }) => r.n} emptyTitle="Aucun compte" />);
  expect(vide.textContent).toContain("Aucun compte");
  const charg = await render(<Table columns={cols} rows={[]} rowKey={(r: { n: string }) => r.n} loading />);
  expect(charg.querySelectorAll("[data-loading-row]").length).toBeGreaterThan(0);
  expect(charg.textContent).not.toContain("Aucun résultat");
});

test("ConfirmDialog : confirmation impossible sans motif", async () => {
  const onConfirm = vi.fn();
  const div = await render(
    <ConfirmDialog open title="Rejeter la demande" reasonLabel="Motif" confirmLabel="Rejeter" onConfirm={onConfirm} onCancel={() => {}} />,
  );
  const confirm = byText(div, "button", "Rejeter") as HTMLButtonElement;
  expect(confirm.disabled).toBe(true);
  await click(confirm);
  expect(onConfirm).not.toHaveBeenCalled();

  await type(div.querySelector("textarea")!, "   ");
  expect((byText(div, "button", "Rejeter") as HTMLButtonElement).disabled).toBe(true);

  await type(div.querySelector("textarea")!, "Photo illisible");
  const ok = byText(div, "button", "Rejeter") as HTMLButtonElement;
  expect(ok.disabled).toBe(false);
  await click(ok);
  expect(onConfirm).toHaveBeenCalledWith("Photo illisible");
});

test("ConfirmDialog : sans motif demandé, confirme directement ; Échap annule", async () => {
  const onConfirm = vi.fn();
  const onCancel = vi.fn();
  const div = await render(<ConfirmDialog open title="Supprimer" onConfirm={onConfirm} onCancel={onCancel} />);
  expect(div.querySelector("textarea")).toBeNull();
  expect(document.querySelector('[role="dialog"]')).not.toBeNull();
  await act(async () => {
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
  });
  expect(onCancel).toHaveBeenCalledOnce();
  await click(byText(div, "button", "Confirmer"));
  expect(onConfirm).toHaveBeenCalledWith(undefined);
});

test("ConfirmDialog : fermé, rien n'est affiché", async () => {
  const div = await render(<ConfirmDialog open={false} title="X" onConfirm={() => {}} onCancel={() => {}} />);
  expect(div.querySelector('[role="dialog"]')).toBeNull();
});

test("Pagination : bornes et changement de page", async () => {
  const onPageChange = vi.fn();
  const div = await render(<Pagination page={1} pageCount={3} onPageChange={onPageChange} />);
  expect((byText(div, "button", "Précédent") as HTMLButtonElement).disabled).toBe(true);
  await click(byText(div, "button", "Suivant"));
  expect(onPageChange).toHaveBeenCalledWith(2);
  expect(div.textContent).toContain("Page 1 sur 3");
});

test("Pagination : une seule page, rien à afficher", async () => {
  const div = await render(<Pagination page={1} pageCount={1} onPageChange={() => {}} />);
  expect(div.querySelector("nav")).toBeNull();
});

function Trigger() {
  const toast = useToast();
  return (
    <>
      <button onClick={() => toast.success("Compte validé")}>ok</button>
      <button onClick={() => toast.error("Échec")}>ko</button>
    </>
  );
}

test("Toast : succès et erreur, disparition automatique", async () => {
  vi.useFakeTimers();
  const div = await render(
    <ToastProvider duration={1000}>
      <Trigger />
    </ToastProvider>,
  );
  await click(byText(div, "button", "ok"));
  await click(byText(div, "button", "ko"));
  expect(div.querySelector('[role="status"]')?.textContent).toContain("Compte validé");
  expect(div.querySelector('[role="alert"]')?.textContent).toContain("Échec");
  await act(async () => {
    vi.advanceTimersByTime(1100);
  });
  expect(div.querySelector('[role="status"]')).toBeNull();
  expect(div.querySelector('[role="alert"]')).toBeNull();
});

test("useToast hors fournisseur : erreur explicite", async () => {
  const spy = vi.spyOn(console, "error").mockImplementation(() => {});
  await expect(render(<Trigger />)).rejects.toThrow("ToastProvider");
  spy.mockRestore();
});
