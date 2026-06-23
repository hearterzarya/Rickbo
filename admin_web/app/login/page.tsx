"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Shield, ArrowRight, RefreshCcw, Phone } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Separator } from "@/components/ui/separator";
import { useAuthStore, errorMessage } from "@/lib/auth";
import { DEFAULT_API_BASE_URL, getApiBaseUrl, setApiBaseUrl } from "@/lib/env";

export default function LoginPage() {
  const router = useRouter();
  const login = useAuthStore((s) => s.login);
  const token = useAuthStore((s) => s.token);
  const hydrated = useAuthStore((s) => s.hydrated);

  const [phone, setPhone] = useState("9999000111");
  const [apiUrl, setApiUrl] = useState(DEFAULT_API_BASE_URL);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    setApiUrl(getApiBaseUrl());
  }, []);

  useEffect(() => {
    if (hydrated && token) router.replace("/dashboard");
  }, [hydrated, token, router]);

  async function handleLogin() {
    setErr(null);
    if (phone.replace(/\D/g, "").length !== 10) {
      setErr("10 अंकों का phone डालें (10-digit phone required)");
      return;
    }
    setLoading(true);
    try {
      await login(phone);
      toast.success("Welcome back, admin");
      router.replace("/dashboard");
    } catch (e) {
      setErr(errorMessage(e));
      toast.error(errorMessage(e));
    } finally {
      setLoading(false);
    }
  }

  function handleSaveApiUrl() {
    setApiBaseUrl(apiUrl);
    toast.success(`API URL saved → ${apiUrl}`);
  }

  function handleResetApiUrl() {
    const local = "http://localhost:4000";
    setApiUrl(local);
    setApiBaseUrl(local);
    toast.success(`Reset to ${local}`);
  }

  return (
    <div className="grid min-h-screen place-items-center bg-gradient-to-br from-background to-muted/40 p-6">
      <div className="w-full max-w-md rounded-2xl border border-border bg-card p-8 shadow-2xl shadow-black/40">
        <div className="mb-6 flex flex-col items-center text-center">
          <div className="mb-3 flex h-14 w-14 items-center justify-center rounded-2xl bg-primary/15">
            <Shield className="h-7 w-7 text-primary" />
          </div>
          <h1 className="text-2xl font-bold tracking-tight">Rickbo Admin</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Operations + Safety Control Room
          </p>
        </div>

        <div className="space-y-3">
          <Label htmlFor="phone" className="text-sm">
            Admin phone / ऐडमिन फ़ोन
          </Label>
          <div className="relative">
            <Phone className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              id="phone"
              type="tel"
              inputMode="numeric"
              maxLength={10}
              value={phone}
              onChange={(e) => setPhone(e.target.value.replace(/\D/g, ""))}
              className="pl-9"
              autoFocus
            />
          </div>

          {err && (
            <div className="rounded-md border border-destructive/40 bg-destructive/10 p-3 text-xs text-destructive">
              {err}
            </div>
          )}

          <Button onClick={handleLogin} disabled={loading} className="w-full" size="lg">
            {loading ? (
              "Logging in…"
            ) : (
              <>
                Admin Login
                <ArrowRight className="ml-2 h-4 w-4" />
              </>
            )}
          </Button>
        </div>

        <Separator className="my-6" />

        <div className="space-y-3">
          <Label className="text-sm">API base URL / API पता</Label>
          <Input
            value={apiUrl}
            onChange={(e) => setApiUrl(e.target.value)}
            placeholder="https://rickbo-production.up.railway.app"
          />
          <p className="text-xs leading-relaxed text-muted-foreground">
            Web (this): Railway URL or <code>http://localhost:4000</code>
            <br />
            Dev: <code>http://10.0.2.2:4000</code> (emulator) or PC LAN IP
          </p>
          <div className="grid grid-cols-2 gap-2">
            <Button onClick={handleSaveApiUrl} variant="outline" size="sm">
              Save API URL
            </Button>
            <Button
              onClick={handleResetApiUrl}
              variant="outline"
              size="sm"
              className="border-emerald-600/40 text-emerald-500 hover:text-emerald-400"
            >
              <RefreshCcw className="mr-1 h-3 w-3" /> Reset → :4000
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
