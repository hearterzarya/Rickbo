"use client";

import { useEffect } from "react";
import { useRouter, usePathname } from "next/navigation";
import Link from "next/link";
import {
  LayoutDashboard,
  Users,
  Car,
  Map,
  Siren,
  LogOut,
  PhoneCall,
  MapPin,
  Shield,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { useAuthStore, useAuthHydrated } from "@/lib/auth";
import { cn, maskPhone } from "@/lib/utils";

const NAV = [
  { href: "/dashboard", label: "Dashboard / डैशबोर्ड", icon: LayoutDashboard },
  { href: "/users", label: "Users / यात्री", icon: Users },
  { href: "/drivers", label: "Drivers / ड्राइवर", icon: Car },
  { href: "/rides", label: "Rides / सवारी", icon: MapPin },
  { href: "/sos", label: "SOS / आपातकाल", icon: Siren },
  { href: "/zones", label: "Zones / क्षेत्र", icon: Map },
];

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const token = useAuthStore((s) => s.token);
  const phone = useAuthStore((s) => s.phone);
  const logout = useAuthStore((s) => s.logout);
  const hydrated = useAuthHydrated();

  useEffect(() => {
    if (hydrated && !token) router.replace("/login");
  }, [hydrated, token, router]);

  // Don't render the shell until the auth store has rehydrated.
  if (!hydrated) {
    return (
      <div className="grid h-screen place-items-center text-muted-foreground">
        Loading…
      </div>
    );
  }
  if (!token) return null;

  return (
    <div className="flex min-h-screen bg-background">
      {/* Sidebar */}
      <aside className="hidden w-64 shrink-0 border-r border-border bg-card md:flex md:flex-col">
        <div className="flex h-16 items-center gap-2 border-b border-border px-5">
          <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary/15">
            <Shield className="h-5 w-5 text-primary" />
          </div>
          <div>
            <p className="text-sm font-semibold leading-tight">Rickbo</p>
            <p className="text-[11px] text-muted-foreground">Admin / ऐडमिन</p>
          </div>
        </div>

        <nav className="flex-1 space-y-1 p-3">
          {NAV.map(({ href, label, icon: Icon }) => {
            const active = pathname === href || pathname?.startsWith(href + "/");
            return (
              <Link
                key={href}
                href={href}
                className={cn(
                  "flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition",
                  active
                    ? "bg-primary/15 text-primary"
                    : "text-muted-foreground hover:bg-muted hover:text-foreground",
                )}
              >
                <Icon className="h-4 w-4" />
                {label}
              </Link>
            );
          })}
        </nav>

        <Separator />

        <div className="p-4">
          <div className="mb-3 rounded-lg border border-border bg-muted/40 p-3 text-xs">
            <p className="font-semibold text-foreground">Signed in as</p>
            <p className="mt-0.5 flex items-center gap-1 text-muted-foreground">
              <PhoneCall className="h-3 w-3" />
              {phone ? maskPhone(phone) : "—"}
            </p>
          </div>
          <Button
            variant="outline"
            size="sm"
            className="w-full"
            onClick={() => {
              logout();
              router.replace("/login");
            }}
          >
            <LogOut className="mr-2 h-3.5 w-3.5" /> Logout
          </Button>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-x-hidden">
        {/* Mobile top bar */}
        <header className="flex h-16 items-center justify-between border-b border-border bg-card px-4 md:hidden">
          <div className="flex items-center gap-2">
            <Shield className="h-5 w-5 text-primary" />
            <span className="font-semibold">Rickbo Admin</span>
          </div>
          <Button
            variant="ghost"
            size="icon"
            onClick={() => {
              logout();
              router.replace("/login");
            }}
          >
            <LogOut className="h-4 w-4" />
          </Button>
        </header>

        {/* Page nav (mobile) */}
        <nav className="flex gap-1 overflow-x-auto border-b border-border bg-card p-2 md:hidden">
          {NAV.map(({ href, label, icon: Icon }) => {
            const active = pathname === href;
            return (
              <Link
                key={href}
                href={href}
                className={cn(
                  "flex shrink-0 items-center gap-2 rounded-md px-3 py-2 text-xs",
                  active ? "bg-primary/15 text-primary" : "text-muted-foreground",
                )}
              >
                <Icon className="h-3.5 w-3.5" />
                {label.split(" / ")[0]}
              </Link>
            );
          })}
        </nav>

        <div className="p-6 md:p-8">{children}</div>
      </main>
    </div>
  );
}
