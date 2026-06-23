// Typed fetch wrapper for the NestJS /admin/* + /auth/* endpoints.
// Adds Authorization header from zustand store, normalizes errors,
// and supports an AbortSignal for SWR cancellation.

import { getApiBaseUrl } from "./env";
import { useAuthStore } from "./auth";

export class ApiError extends Error {
  status: number;
  body: unknown;
  constructor(message: string, status: number, body: unknown) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.body = body;
  }
}

async function request<T>(
  path: string,
  init: RequestInit = {},
  signal?: AbortSignal,
): Promise<T> {
  const base = getApiBaseUrl().replace(/\/$/, "");
  const token = useAuthStore.getState().token;

  const res = await fetch(`${base}${path}`, {
    ...init,
    signal,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(init.headers || {}),
    },
  });

  // 401 → drop the session and bounce to /login. SWR swallows the error
  // so we do the redirect from a window listener instead.
  if (res.status === 401) {
    useAuthStore.getState().logout();
    if (typeof window !== "undefined" && !window.location.pathname.startsWith("/login")) {
      window.location.href = "/login";
    }
  }

  const text = await res.text();
  const body: unknown = text ? safeJson(text) : null;

  if (!res.ok) {
    const message =
      (body as { message?: string })?.message ||
      res.statusText ||
      `HTTP ${res.status}`;
    throw new ApiError(message, res.status, body);
  }
  return body as T;
}

function safeJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

export const api = {
  get: <T>(path: string, signal?: AbortSignal) =>
    request<T>(path, { method: "GET" }, signal),
  post: <T>(path: string, body?: unknown, signal?: AbortSignal) =>
    request<T>(path, { method: "POST", body: JSON.stringify(body ?? {}) }, signal),
};

// SWR fetcher: SWR calls us with the key (the path) plus an options bag
// carrying an AbortSignal. We use the key as the API path.
export const swrFetcher = <T>(key: string, options?: { signal?: AbortSignal }) =>
  request<T>(key, { method: "GET" }, options?.signal);
