import { api } from "../../api/client";
import { ENDPOINTS } from "../../api/endpoints";

/** « downloaded » : fichier remis au navigateur ; « refused » : en-têtes interdits, rien téléchargé. */
export type ExportOutcome = "downloaded" | "refused";

/** Mots interdits dans les en-têtes de colonnes (garde-fou, insensible à la casse). */
// Comparés après normalisation NFKC et retrait de tout ce qui n'est pas lettre/chiffre.
const FORBIDDEN_HEADERS = ["cni", "token", "jeton", "password", "motdepasse", "cartenationale"];
/** Délai avant de révoquer le blob URL : laisse le temps à Firefox/Safari de démarrer le téléchargement. */
export const REVOKE_DELAY_MS = 3000;
const HEADER_BYTES = 4096;

/** Date locale Africa/Douala au format AAAA-MM-JJ. */
export function doualaDate(now: Date = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Africa/Douala", year: "numeric", month: "2-digit", day: "2-digit" }).format(now);
}

export function defaultExportName(now: Date = new Date()): string {
  return `netbuis-comptes-${doualaDate(now)}.csv`;
}

/** Nom de fichier du serveur (Content-Disposition) : sans chemin ni caractère de contrôle, sinon nom par défaut. */
export function safeExportName(contentDisposition: unknown, now: Date = new Date()): string {
  const fallback = defaultExportName(now);
  if (typeof contentDisposition !== "string") return fallback;
  const m = /filename\s*=\s*(?:"([^"]*)"|([^;]*))/i.exec(contentDisposition);
  const raw = (m?.[1] ?? m?.[2] ?? "").trim();
  if (raw === "" || /[\u0000-\u001f\u007f/\\]/.test(raw)) return fallback;
  if (raw.startsWith(".") || !/^[A-Za-z0-9._-]{1,100}$/.test(raw) || !/\.csv$/i.test(raw)) return fallback;
  return raw;
}

function readStart(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result ?? ""));
    reader.onerror = () => reject(reader.error);
    reader.readAsText(blob.slice(0, HEADER_BYTES), "utf-8");
  });
}

/** Vrai si la première ligne du CSV nomme une colonne interdite (CNI, jeton, mot de passe). */
export function hasForbiddenHeader(csvStart: string): boolean {
  const first = csvStart.replace(/^\uFEFF/, "").split(/\r?\n/, 1)[0] ?? "";
  return first
    .split(/[;,\t]/)
    .map((h) => h.normalize("NFKC").toLowerCase().replace(/[^\p{L}\p{N}]/gu, ""))
    .some((h) => FORBIDDEN_HEADERS.some((f) => h.includes(f)));
}

const pending = new Map<ReturnType<typeof setTimeout>, string>();

/** Révoque tout de suite les blob URL en attente (démontage de la page). */
export function flushPendingRevocations(): void {
  for (const [timer, url] of pending) {
    clearTimeout(timer);
    URL.revokeObjectURL(url);
  }
  pending.clear();
}

function triggerDownload(blob: Blob, name: string): void {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  try {
    a.href = url;
    a.download = name;
    a.style.display = "none";
    document.body.appendChild(a);
    a.click();
  } catch (e) {
    URL.revokeObjectURL(url); // échec : une seule révocation, aucune en attente
    throw e;
  } finally {
    a.remove();
  }
  const timer = setTimeout(() => {
    pending.delete(timer);
    URL.revokeObjectURL(url);
  }, REVOKE_DELAY_MS);
  pending.set(timer, url);
}

/** GET authentifié (jeton) de l'export, puis téléchargement. Le contenu n'est ni gardé ni affiché ni journalisé. */
export async function downloadAccountsExport(): Promise<ExportOutcome> {
  const res = await api.get<Blob>(ENDPOINTS.exportAccounts, { responseType: "blob" });
  const blob = res.data;
  if (hasForbiddenHeader(await readStart(blob))) return "refused";
  triggerDownload(blob, safeExportName((res.headers as Record<string, unknown> | undefined)?.["content-disposition"]));
  return "downloaded";
}
