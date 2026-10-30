/** Page provisoire : remplacée par l'écran réel de sa tâche (T081, T082, T083, T113). */
export function ComingSoonPage({ title }: { title: string }) {
  return (
    <section className="p-8" aria-label={title}>
      <h1 className="text-2xl font-semibold">{title}</h1>
      <p className="mt-2 text-ink-2">Cette page arrive bientôt.</p>
    </section>
  );
}
