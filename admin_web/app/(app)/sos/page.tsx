"use client";

import { useState } from "react";
import useSWR from "swr";
import { toast } from "sonner";
import { ShieldCheck, RefreshCcw, Siren } from "lucide-react";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { api, swrFetcher } from "@/lib/api";
import { errorMessage } from "@/lib/auth";
import { formatDate, formatRelative, maskPhone, cn } from "@/lib/utils";
import type { SosEvent } from "@/lib/types";

const FILTERS: Array<{ key: "all" | "open" | "resolved"; label: string }> = [
  { key: "all", label: "All" },
  { key: "open", label: "Open" },
  { key: "resolved", label: "Resolved" },
];

export default function SosPage() {
  const [filter, setFilter] = useState<"all" | "open" | "resolved">("open");
  const path =
    filter === "all"
      ? "/admin/sos"
      : `/admin/sos?resolved=${filter === "resolved"}`;
  const { data, mutate, isLoading } = useSWR<SosEvent[]>(
    path,
    swrFetcher,
    { refreshInterval: 5000 },
  );
  const [pending, setPending] = useState<SosEvent | null>(null);
  const [notes, setNotes] = useState("");
  const [busy, setBusy] = useState(false);

  async function resolve() {
    if (!pending) return;
    setBusy(true);
    try {
      await api.post(`/admin/sos/${pending.id}/resolve`, { notes: notes || undefined });
      toast.success(`SOS resolved • ${maskPhone(pending.ride.user.phone)}`);
      setPending(null);
      setNotes("");
      mutate();
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="flex items-center gap-2 text-3xl font-bold tracking-tight">
            <Siren className="h-7 w-7 text-destructive" /> SOS / आपातकाल
          </h1>
          <p className="text-sm text-muted-foreground">
            Safety alerts from users + drivers
          </p>
        </div>
        <Button variant="outline" size="icon" onClick={() => mutate()}>
          <RefreshCcw className="h-4 w-4" />
        </Button>
      </div>

      <Tabs value={filter} onValueChange={(v) => setFilter(v as typeof filter)}>
        <TabsList>
          {FILTERS.map((f) => (
            <TabsTrigger key={f.key} value={f.key}>
              {f.label}
            </TabsTrigger>
          ))}
        </TabsList>
      </Tabs>

      <Card>
        <CardHeader>
          <CardTitle>
            {filter === "all"
              ? "All SOS events"
              : filter === "open"
                ? "Open SOS events"
                : "Resolved SOS events"}
          </CardTitle>
          <CardDescription>{data?.length ?? 0} returned</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          {isLoading ? (
            <div className="space-y-2">
              <Skeleton className="h-20 w-full" />
              <Skeleton className="h-20 w-full" />
            </div>
          ) : (data?.length ?? 0) === 0 ? (
            <p className="rounded-md border border-dashed border-border bg-muted/20 p-8 text-center text-sm text-muted-foreground">
              कोई SOS नहीं — All clear ✓
            </p>
          ) : (
            data?.map((e) => (
              <div
                key={e.id}
                className={cn(
                  "rounded-lg border p-4",
                  e.resolved
                    ? "border-border bg-muted/30"
                    : "border-destructive/40 bg-destructive/5",
                )}
              >
                <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                  <div>
                    <div className="flex items-center gap-2">
                      <Badge variant={e.resolved ? "secondary" : "destructive"}>
                        {e.raisedBy} raised
                      </Badge>
                      {e.resolved ? (
                        <Badge variant="outline" className="border-emerald-500/40 text-emerald-500">
                          RESOLVED
                        </Badge>
                      ) : (
                        <Badge variant="outline" className="border-destructive/40 text-destructive">
                          OPEN
                        </Badge>
                      )}
                      <span className="text-xs text-muted-foreground">
                        {formatDate(e.createdAt)} • {formatRelative(e.createdAt)}
                      </span>
                    </div>
                    <div className="mt-2 grid gap-1 text-sm sm:grid-cols-2">
                      <p>
                        <span className="text-muted-foreground">User / यात्री: </span>
                        {maskPhone(e.ride.user.phone)}
                      </p>
                      <p>
                        <span className="text-muted-foreground">Driver / ड्राइवर: </span>
                        {e.ride.driver ? maskPhone(e.ride.driver.phone) : "—"}
                      </p>
                      <p className="font-mono text-xs text-muted-foreground">
                        Ride: {e.rideId}
                      </p>
                      <p className="font-mono text-xs text-muted-foreground">
                        📍 {e.lat.toFixed(4)}, {e.lng.toFixed(4)}
                      </p>
                    </div>
                    {e.notes && (
                      <p className="mt-2 text-xs italic text-muted-foreground">
                        Notes: {e.notes}
                      </p>
                    )}
                  </div>
                  {!e.resolved && (
                    <Button
                      size="sm"
                      className="bg-emerald-600 text-white hover:bg-emerald-500"
                      onClick={() => setPending(e)}
                    >
                      <ShieldCheck className="mr-1 h-3.5 w-3.5" /> Resolve
                    </Button>
                  )}
                </div>
              </div>
            ))
          )}
        </CardContent>
      </Card>

      <Dialog open={!!pending} onOpenChange={(o) => !o && setPending(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Resolve this SOS?</DialogTitle>
            <DialogDescription>
              {pending && (
                <>
                  {pending.raisedBy} raised • {maskPhone(pending.ride.user.phone)}
                  <br />
                  <span className="text-xs text-muted-foreground">
                    {formatDate(pending.createdAt)}
                  </span>
                </>
              )}
            </DialogDescription>
          </DialogHeader>
          <Textarea
            placeholder="Resolution notes (optional) — क्या हुआ, क्या action लिया…"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={4}
          />
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => {
                setPending(null);
                setNotes("");
              }}
              disabled={busy}
            >
              Cancel
            </Button>
            <Button
              onClick={resolve}
              disabled={busy}
              className="bg-emerald-600 text-white hover:bg-emerald-500"
            >
              {busy ? "Resolving…" : "Mark resolved"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
