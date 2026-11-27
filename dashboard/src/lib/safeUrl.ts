// Adresses venant du serveur (photos) : seule une adresse web sûre devient un `src` d'image.
// Refusés : javascript:, data:, blob:, file:, adresses avec identifiants (utilisateur:mot de passe@).

const LOCAL_HOSTS = new Set(["localhost", "127.0.0.1", "[::1]"]);

/** Renvoie l'adresse telle quelle si elle est relative, en https, ou en http vers la machine locale (développement) ; sinon null. */
export function safeImageUrl(value: string | null | undefined): string | null {
  if (typeof value !== "string" || value.trim() === "" || value !== value.trim()) return null;
  // Les adresses « //hôte/… » (sans protocole) sont refusées : elles changeraient d'hôte sans que ça se voie.
  if (value.startsWith("//") || value.startsWith("/\\")) return null;
  // Chemin relatif au site (« /media/... ») : même origine que le tableau de bord.
  if (value.startsWith("/")) return /[\\\s]/.test(value) ? null : value;
  let parsed: URL;
  try {
    parsed = new URL(value); // sans base : une adresse sans protocole (« a.jpg ») est refusée
  } catch {
    return null;
  }
  if (parsed.username !== "" || parsed.password !== "") return null;
  if (parsed.protocol === "https:") return value;
  if (parsed.protocol === "http:" && LOCAL_HOSTS.has(parsed.hostname)) return value;
  return null;
}
