// Sonnerie produite par le navigateur (aucun fichier audio). Un navigateur n'autorise le son qu'après
// un geste de l'utilisateur : `unlockAudio()` est appelé au clic sur « Disponible ».
type AudioCtor = typeof AudioContext;

let context: AudioContext | null = null;
let timer: ReturnType<typeof setInterval> | null = null;

function audioConstructor(): AudioCtor | null {
  const w = globalThis as unknown as { AudioContext?: AudioCtor; webkitAudioContext?: AudioCtor };
  return w.AudioContext ?? w.webkitAudioContext ?? null;
}

/** Prépare le son (à appeler depuis un clic). Sans effet si le navigateur n'a pas d'audio. */
export function unlockAudio(): void {
  const Ctor = audioConstructor();
  if (!Ctor) return;
  try {
    context ??= new Ctor();
    if (context.state === "suspended") void context.resume();
  } catch {
    context = null;
  }
}

function beep(ctx: AudioContext, offset: number): void {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  const start = ctx.currentTime + offset;
  osc.type = "sine";
  osc.frequency.value = 880;
  gain.gain.setValueAtTime(0, start);
  gain.gain.linearRampToValueAtTime(0.25, start + 0.02);
  gain.gain.linearRampToValueAtTime(0, start + 0.4);
  osc.connect(gain).connect(ctx.destination);
  osc.start(start);
  osc.stop(start + 0.45);
}

export const RING_PERIOD_MS = 2000;

/** Double bip répété toutes les 2 s, jusqu'à `stopRinging()`. */
export function startRinging(): void {
  if (timer) return;
  const ring = () => {
    if (!context || context.state !== "running") return;
    beep(context, 0);
    beep(context, 0.5);
  };
  ring();
  timer = setInterval(ring, RING_PERIOD_MS);
}

export function stopRinging(): void {
  if (timer) clearInterval(timer);
  timer = null;
}

export function isRinging(): boolean {
  return timer !== null;
}
