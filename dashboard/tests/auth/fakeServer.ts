// À importer EN PREMIER dans un test : remplace le transport d'axios par un faux serveur.
import axios, { AxiosError, type AxiosAdapter, type InternalAxiosRequestConfig } from "axios";

export interface Reply {
  status: number;
  data?: unknown;
  headers?: Record<string, string>;
  network?: boolean;
}
export interface Call {
  method: string;
  url: string;
  auth: string | undefined;
  body: unknown;
  withCredentials: boolean;
}

export const calls: Call[] = [];
export let handler: (call: Call) => Reply = () => ({ status: 404 });

export function setHandler(h: (call: Call) => Reply) {
  handler = h;
}
export const gates = new Map<string, Promise<void>>();
export function resetServer() {
  gates.clear();
  calls.length = 0;
  handler = () => ({ status: 404 });
}
export const count = (url: string) => calls.filter((c) => c.url === url).length;

const adapter: AxiosAdapter = async (config: InternalAxiosRequestConfig) => {
  let body: unknown = config.data;
  if (typeof body === "string") {
    try {
      body = JSON.parse(body);
    } catch {
      /* corps non JSON */
    }
  }
  const call: Call = {
    method: (config.method ?? "get").toLowerCase(),
    url: config.url ?? "",
    auth: config.headers.get("Authorization") as string | undefined,
    body,
    withCredentials: config.withCredentials === true,
  };
  calls.push(call);
  await (gates.get(call.url) ?? Promise.resolve());
  const r = handler(call);
  if (r.network) throw new AxiosError("Network Error", "ERR_NETWORK", config);
  const response = { data: r.data ?? null, status: r.status, statusText: "", headers: r.headers ?? {}, config };
  if (r.status >= 400) {
    throw new AxiosError(`HTTP ${r.status}`, "ERR_BAD_REQUEST", config, null, response);
  }
  return response;
};

axios.defaults.adapter = adapter;
