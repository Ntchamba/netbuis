import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import type { ReactNode } from "react";

const mounted: Array<{ root: Root; div: HTMLElement }> = [];

export async function render(node: ReactNode) {
  const div = document.createElement("div");
  document.body.appendChild(div);
  const root = createRoot(div);
  mounted.push({ root, div });
  await act(async () => root.render(node));
  return div;
}

export async function cleanup() {
  for (const { root, div } of mounted.splice(0)) {
    await act(async () => root.unmount());
    div.remove();
  }
}

export async function click(el: Element | null) {
  if (!el) throw new Error("élément introuvable");
  await act(async () => {
    (el as HTMLElement).click();
  });
}

export async function type(el: HTMLTextAreaElement | HTMLInputElement, value: string) {
  const proto = el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
  const setter = Object.getOwnPropertyDescriptor(proto, "value")!.set!;
  await act(async () => {
    setter.call(el, value);
    el.dispatchEvent(new Event("input", { bubbles: true }));
  });
}

export function byText(root: ParentNode, selector: string, text: string) {
  return Array.from(root.querySelectorAll(selector)).find((e) => e.textContent?.trim() === text) ?? null;
}
