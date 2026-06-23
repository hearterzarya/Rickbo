// Admin web env config — read at build time via NEXT_PUBLIC_*
// Default points at the live Railway backend; the login screen lets the
// operator override this for a local NestJS dev server.

export const DEFAULT_API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL || "https://rickbo-production.up.railway.app";

const STORAGE_KEY = "rickbo_admin_api_base_url";

export function getApiBaseUrl(): string {
  if (typeof window === "undefined") return DEFAULT_API_BASE_URL;
  return window.localStorage.getItem(STORAGE_KEY) || DEFAULT_API_BASE_URL;
}

export function setApiBaseUrl(url: string): void {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(STORAGE_KEY, url);
}
