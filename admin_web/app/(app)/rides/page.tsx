"use client";

import { useState } from "react";
import useSWR from "swr";
import { toast } from "sonner";
import { RefreshCcw, X } from "lucide-react";
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
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { api, swrFetcher } from "@/lib/api";
import { errorMessage } from "@/lib/auth";
import { formatDate, formatINR, formatRelative, maskPhone, cn } from "@/lib/utils";
import type { Ride, RideStatus } from "@/lib/types";

const STATUSES: Array<{ key: "ALL" | RideStatus; label: string }> = [
  { key: "ALL", label: "All" },
  { key: "REQUESTED", label: "Requested" },
  { key: "MATCHED", label: "Matched" },
  { key: "ONGOING", label: "Ongoing" },
  { key: "COMPLETED", label: "Completed" },
  { key: "CANCELLED", label: "Cancelled" },
];

const STATUS_COLORS: Record<RideStatus, string> = {
  REQUESTED: "bg-yellow-500/15 text-yellow-500",
  MATCHED: "bg-blue-500/15 text-blue-500",
  ARRIVED: "bg-cyan-500/15 text-cyan-500",
  ONGOING: "bg-emerald-500/15 text-emerald-500",
  COMPLETED: "bg-muted text-muted-foreground",
  CANCELLED: "bg-destructive/15 text-destructive",
};

export default function RidesPage() {
  const [status, setStatus] = useState<"ALL" | RideStatus>("ALL");
  const query = status === "ALL" ? "/admin/rides" : `/admin/rides?status=${status}`;
  const { data, mutate, isLoading } = useSWR<Ride[]>(
    query,
    swrFetcher,
    { refreshInterval: 10000 },
  );
  const [pending, setPending] = useState<Ride | null>(null);
  const [busy, setBusy] = useState(false);

  async function cancel() {
    if (!pending) return;
    setBusy(true);
    try {
      await api.post(`/admin/rides/${pending.id}/cancel`);
      toast.success(`Ride cancelled: ${pending.fromZone} → ${pending.toZone}`);
      setPending(null);
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
          <h1 className="text-3xl font-bold tracking-tight">Rides / सवारी</h1>
          <p className="text-sm text-muted-foreground">All bookings, filterable by status</p>
        </div>
        <Button variant="outline" size="icon" onClick={() => mutate()}>
          <RefreshCcw className="h-4 w-4" />
        </Button>
      </div>

      <Tabs value={status} onValueChange={(v) => setStatus(v as "ALL" | RideStatus)}>
        <TabsList>
          {STATUSES.map((s) => (
            <TabsTrigger key={s.key} value={s.key}>
              {s.label}
            </TabsTrigger>
          ))}
        </TabsList>
      </Tabs>

      <Card>
        <CardHeader>
          <CardTitle>{status === "ALL" ? "All rides" : `${status} rides`}</CardTitle>
          <CardDescription>{data?.length ?? 0} returned</CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="space-y-2">
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
            </div>
          ) : (data?.length ?? 0) === 0 ? (
            <p className="rounded-md border border-dashed border-border bg-muted/20 p-8 text-center text-sm text-muted-foreground">
              कोई सवारी नहीं मिली — No rides
            </p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Route / रास्ता</TableHead>
                  <TableHead>User / यात्री</TableHead>
                  <TableHead>Driver / ड्राइवर</TableHead>
                  <TableHead>Fare / किराया</TableHead>
                  <TableHead>Mode</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Requested / समय</TableHead>
                  <TableHead className="text-right">Action</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data?.map((r) => {
                  const canCancel = !["COMPLETED", "CANCELLED"].includes(r.status);
                  return (
                    <TableRow key={r.id}>
                      <TableCell className="font-medium">
                        {r.fromZone} → {r.toZone}
                        <div className="text-xs text-muted-foreground">
                          {r.passengerCount} पैसेंजर
                        </div>
                      </TableCell>
                      <TableCell className="font-mono text-xs">
                        {r.user.name || "—"}
                        <div className="text-muted-foreground">{maskPhone(r.user.phone)}</div>
                      </TableCell>
                      <TableCell className="font-mono text-xs">
                        {r.driver ? (
                          <>
                            {r.driver.rickshawNumber || r.driver.phone}
                            <div className="text-muted-foreground">
                              {r.driver.name || maskPhone(r.driver.phone)}
                            </div>
                          </>
                        ) : (
                          <span className="text-muted-foreground">—</span>
                        )}
                      </TableCell>
                      <TableCell className="font-semibold">{formatINR(r.fare)}</TableCell>
                      <TableCell>
                        <Badge variant="outline">{r.mode}</Badge>
                      </TableCell>
                      <TableCell>
                        <span
                          className={cn(
                            "rounded-full px-2 py-0.5 text-xs font-medium",
                            STATUS_COLORS[r.status],
                          )}
                        >
                          {r.status}
                        </span>
                      </TableCell>
                      <TableCell className="text-xs text-muted-foreground">
                        {formatDate(r.requestedAt)}
                        <div>{formatRelative(r.requestedAt)}</div>
                      </TableCell>
                      <TableCell className="text-right">
                        {canCancel && (
                          <Button
                            size="sm"
                            variant="outline"
                            className="border-destructive/40 text-destructive"
                            onClick={() => setPending(r)}
                          >
                            <X className="mr-1 h-3.5 w-3.5" /> Cancel
                          </Button>
                        )}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <Dialog open={!!pending} onOpenChange={(o) => !o && setPending(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Cancel this ride?</DialogTitle>
            <DialogDescription>
              {pending && (
                <>
                  {pending.fromZone} → {pending.toZone} • {formatINR(pending.fare)}
                  <br />
                  <span className="font-mono text-xs">{pending.id}</span>
                </>
              )}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPending(null)} disabled={busy}>
              Keep ride
            </Button>
            <Button
              onClick={cancel}
              disabled={busy}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              {busy ? "Cancelling…" : "Cancel ride"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
