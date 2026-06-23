"use client";

import useSWR from "swr";
import {
  Users,
  Car,
  Radio,
  Activity,
  Siren,
  ArrowUpRight,
  RefreshCw,
} from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { swrFetcher } from "@/lib/api";
import { formatRelative, cn } from "@/lib/utils";
import type { AdminStats, Ride, SosEvent } from "@/lib/types";

const REFRESH_MS = 5000;

export default function DashboardPage() {
  const stats = useSWR<AdminStats>("/admin/stats", swrFetcher, {
    refreshInterval: REFRESH_MS,
  });
  const rides = useSWR<Ride[]>(
    "/admin/rides?status=ONGOING",
    swrFetcher,
    { refreshInterval: REFRESH_MS },
  );
  const sos = useSWR<SosEvent[]>(
    "/admin/sos?resolved=false",
    swrFetcher,
    { refreshInterval: REFRESH_MS },
  );

  const loading = stats.isLoading || rides.isLoading || sos.isLoading;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Dashboard</h1>
          <p className="text-sm text-muted-foreground">
            रियल-टाइम ऑपरेशन्स + सेफ़्टी • auto-refresh every {REFRESH_MS / 1000}s
          </p>
        </div>
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              stats.mutate();
              rides.mutate();
              sos.mutate();
            }}
          >
            <RefreshCw className="mr-2 h-3.5 w-3.5" /> Refresh
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={() => (window.location.href = "/sos")}
            className="border-destructive/40 text-destructive hover:text-destructive"
          >
            <Siren className="mr-2 h-3.5 w-3.5" /> Open SOS ({stats.data?.openSos ?? "—"})
          </Button>
        </div>
      </div>

      {/* Stat grid */}
      <div className="grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-6">
        <StatCard
          label="Users / यात्री"
          value={stats.data?.users}
          icon={Users}
          loading={loading}
        />
        <StatCard
          label="Drivers / ड्राइवर"
          value={stats.data?.drivers}
          icon={Car}
          loading={loading}
        />
        <StatCard
          label="Online / ऑनलाइन"
          value={stats.data?.activeDrivers}
          icon={Radio}
          accent
          loading={loading}
        />
        <StatCard
          label="Rides Today / आज"
          value={stats.data?.ridesToday}
          icon={Activity}
          loading={loading}
        />
        <StatCard
          label="Ongoing / चालू"
          value={stats.data?.ongoingRides}
          icon={ArrowUpRight}
          loading={loading}
        />
        <StatCard
          label="Open SOS / खुले SOS"
          value={stats.data?.openSos}
          icon={Siren}
          danger
          loading={loading}
        />
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        {/* Ongoing rides */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0">
            <div>
              <CardTitle>Ongoing rides / चालू सवारी</CardTitle>
              <CardDescription>Currently matched or in-progress</CardDescription>
            </div>
            <Badge variant="secondary">{rides.data?.length ?? 0}</Badge>
          </CardHeader>
          <CardContent className="space-y-2">
            {loading && <Skeleton className="h-12 w-full" />}
            {!loading && (rides.data?.length ?? 0) === 0 && (
              <Empty text="कोई चालू सवारी नहीं — No active rides" />
            )}
            {rides.data?.slice(0, 6).map((r) => (
              <div
                key={r.id}
                className="flex items-center justify-between rounded-lg border border-border bg-muted/30 px-3 py-2 text-sm"
              >
                <div>
                  <p className="font-medium">
                    {r.fromZone} → {r.toZone}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    {r.user.phone}
                    {r.driver && ` • ${r.driver.rickshawNumber ?? r.driver.phone}`}
                  </p>
                </div>
                <div className="text-right text-xs">
                  <Badge variant="outline">{r.status}</Badge>
                  <p className="mt-1 text-muted-foreground">{formatRelative(r.requestedAt)}</p>
                </div>
              </div>
            ))}
          </CardContent>
        </Card>

        {/* Open SOS */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0">
            <div>
              <CardTitle>Open SOS / खुले SOS</CardTitle>
              <CardDescription>Unresolved safety alerts</CardDescription>
            </div>
            <Badge variant={sos.data && sos.data.length > 0 ? "destructive" : "secondary"}>
              {sos.data?.length ?? 0}
            </Badge>
          </CardHeader>
          <CardContent className="space-y-2">
            {loading && <Skeleton className="h-12 w-full" />}
            {!loading && (sos.data?.length ?? 0) === 0 && (
              <Empty text="कोई खुला SOS नहीं — All clear ✓" />
            )}
            {sos.data?.slice(0, 6).map((e) => (
              <div
                key={e.id}
                className="flex items-center justify-between rounded-lg border border-destructive/40 bg-destructive/10 px-3 py-2 text-sm"
              >
                <div>
                  <p className="font-medium text-destructive">
                    {e.raisedBy} raised • ride {e.rideId.slice(0, 8)}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    {e.ride.user.phone}
                    {e.ride.driver && ` • driver ${e.ride.driver.phone}`}
                  </p>
                </div>
                <div className="text-right text-xs">
                  <p className="font-mono text-muted-foreground">
                    {e.lat.toFixed(3)}, {e.lng.toFixed(3)}
                  </p>
                  <p className="text-muted-foreground">{formatRelative(e.createdAt)}</p>
                </div>
              </div>
            ))}
            {sos.data && sos.data.length > 0 && (
              <Button
                variant="outline"
                size="sm"
                className="w-full border-destructive/40 text-destructive"
                onClick={() => (window.location.href = "/sos")}
              >
                Resolve on SOS page →
              </Button>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function StatCard({
  label,
  value,
  icon: Icon,
  loading,
  accent,
  danger,
}: {
  label: string;
  value: number | undefined;
  icon: React.ComponentType<{ className?: string }>;
  loading: boolean;
  accent?: boolean;
  danger?: boolean;
}) {
  return (
    <Card
      className={cn(
        "transition",
        accent && "border-emerald-500/30 bg-emerald-500/5",
        danger && "border-destructive/30 bg-destructive/5",
      )}
    >
      <CardContent className="flex items-center gap-3 p-4">
        <div
          className={cn(
            "flex h-10 w-10 items-center justify-center rounded-lg",
            accent && "bg-emerald-500/15 text-emerald-500",
            danger && "bg-destructive/15 text-destructive",
            !accent && !danger && "bg-primary/10 text-primary",
          )}
        >
          <Icon className="h-5 w-5" />
        </div>
        <div>
          {loading ? (
            <Skeleton className="h-6 w-12" />
          ) : (
            <p className="text-2xl font-bold leading-none">{value ?? "—"}</p>
          )}
          <p className="mt-1 text-xs text-muted-foreground">{label}</p>
        </div>
      </CardContent>
    </Card>
  );
}

function Empty({ text }: { text: string }) {
  return (
    <div className="rounded-lg border border-dashed border-border bg-muted/20 px-3 py-6 text-center text-sm text-muted-foreground">
      {text}
    </div>
  );
}