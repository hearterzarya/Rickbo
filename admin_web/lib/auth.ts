// Auth store: JWT + phone, persisted to localStorage via zustand persist.
// Avoids SSR cookie plumbing — the admin is a private ops tool, not a
// SEO-sensitive surface.

import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";
import { api, ApiError } from "./api";
import type { LoginResponse } from "./types";

type AdminAuthState = {
  token: string | null;
  phone: string | null;
  hydrated: boolean;
  setHydrated: () => void;
  login: (phone: string) => Promise<void>;
  logout: () => void;
};

export const useAuthStore = create<AdminAuthState>()(
  persist(
    (set) => ({
      token: null,
      phone: null,
      hydrated: false,
      setHydrated: () => set({ hydrated: true }),
      login: async (rawPhone) => {
        const phone = rawPhone.startsWith("+")
          ? rawPhone
          : `+91${rawPhone.replace(/\D/g, "")}`;
        const res = await api.post<LoginResponse>("/auth/test-otp", {
          phone,
          role: "admin",
        });
        set({ token: res.token, phone });
      },
      logout: () => set({ token: null, phone: null }),
    }),
    {
      name: "rickbo_admin_auth",
      storage: createJSONStorage(() => localStorage),
      onRehydrateStorage: () => (state) => {
        state?.setHydrated();
      },
    },
  ),
);

// Hook: call after mount to know if rehydration is done.
export function useAuthHydrated(): boolean {
  return useAuthStore((s) => s.hydrated);
}

// Surface a single error message from any thrown thing in the api layer.
export function errorMessage(e: unknown): string {
  if (e instanceof ApiError) return e.message;
  if (e instanceof Error) return e.message;
  return "Unknown error";
}
