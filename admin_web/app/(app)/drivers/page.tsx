"use client";

import { useState } from "react";
import useSWR from "swr";
import { toast } from "sonner";
import {
  CheckCircle2,
  Search,
  RefreshCcw,
  ShieldX,
  ShieldAlert,
  Star,
} from "lucide-react";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
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
import { maskPhone, cn } from "@/lib/utils";
import type { Driver } from "@/lib/types";

type Action = "approve" | "suspend" | "ban" | "verify-aadhaar" | "verify-police";

const ACTION_LABELS: Record<Action, string> = {
  approve: "Approve → ACTIVE",
  suspend: "Suspend",
  ban: "Ban",
  "verify-aadhaar": "Verify Aadhaar",
  "verify-police": "Verify Police",
};

const STATUS_STYLES: Record<Driver["status"], string> = {
  PENDING: "bg-yellow-500/15 text-yellow-500 border-yellow-500/30",
  ACTIVE: "bg-emerald-500/15 text-emerald-500 border-emerald-500/30",
  SUSPENDED: "bg-orange-500/15 text-orange-500 border-orange-500/30",
  BANNED: "bg-destructive/15 text-destructive border-destructive/30",
};

export default function DriversPage() {
  const { data, mutate, isLoading } = useSWR<Driver[]>(
    "/admin/drivers",
    swrFetcher,
    { refreshInterval: 15000 },
  );
  const [search, setSearch] = useState("");
  const [pending, setPending] = useState<{ driver: Driver; action: Action } | null>(null);
  const [busy, setBusy] = useState(false);

  const filtered =
    data?.filter(
      (d) =>
        d.phone.includes(search) ||
        (d.name ?? "").toLowerCase().includes(search.toLowerCase()) ||
        (d.rickshawNumber ?? "").toLowerCase().includes(search.toLowerCase()),
    ) ?? [];

  async function confirmAction() {
    if (!pending) return;
    setBusy(true);
    try {
      const { driver, action } = pending;
      await api.post(`/admin/drivers/${driver.id}/${action}`);
      toast.success(`${ACTION_LABELS[action]} → ${maskPhone(driver.phone)}`);
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
          <h1 className="text-3xl font-bold tracking-tight">Drivers / ड्राइवर</h1>
          <p className="text-sm text-muted-foreground">
            E-rickshaw drivers on the Rickbo platform
          </p>
        </div>
        <div className="flex gap-2">
          <div className="relative">
            <Search className="absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Phone, name, rickshaw no…"
              className="pl-8 w-72"
            />
          </div>
          <Button variant="outline" size="icon" onClick={() => mutate()}>
            <RefreshCcw className="h-4 w-4" />
          </Button>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>All drivers</CardTitle>
          <CardDescription>{data?.length ?? 0} total</CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="space-y-2">
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
            </div>
          ) : filtered.length === 0 ? (
            <p className="rounded-md border border-dashed border-border bg-muted/20 p-8 text-center text-sm text-muted-foreground">
              कोई ड्राइवर नहीं — No drivers found
            </p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name / नाम</TableHead>
                  <TableHead>Phone / फ़ोन</TableHead>
                  <TableHead>Rickshaw / नंबर</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Online</TableHead>
                  <TableHead>Verifications</TableHead>
                  <TableHead>Rides</TableHead>
                  <TableHead>Rating</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filtered.map((d) => (
                  <TableRow key={d.id}>
                    <TableCell className="font-medium">{d.name || "—"}</TableCell>
                    <TableCell className="font-mono text-xs">
                      {maskPhone(d.phone)}
                    </TableCell>
                    <TableCell className="font-mono text-xs">
                      {d.rickshawNumber || "—"}
                    </TableCell>
                    <TableCell>
                      <span
                        className={cn(
                          "inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-xs font-medium",
                          STATUS_STYLES[d.status],
                        )}
                      >
                        {d.status}
                      </span>
                    </TableCell>
                    <TableCell>
                      {d.isOnline ? (
                        <Badge className="bg-emerald-500/20 text-emerald-500">ON</Badge>
                      ) : (
                        <Badge variant="secondary">OFF</Badge>
                      )}
                    </TableCell>
                    <TableCell>
                      <div className="flex gap-1">
                        <button
                          onClick={() =>
                            setPending({ driver: d, action: "verify-aadhaar" })
                          }
                          className={cn(
                            "rounded border px-1.5 py-0.5 text-[10px] font-semibold transition",
                            d.aadhaarVerified
                              ? "border-emerald-500/40 bg-emerald-500/10 text-emerald-500"
                              : "border-border text-muted-foreground hover:text-foreground",
                          )}
                        >
                          AADHAAR
                        </button>
                        <button
                          onClick={() =>
                            setPending({ driver: d, action: "verify-police" })
                          }
                          className={cn(
                            "rounded border px-1.5 py-0.5 text-[10px] font-semibold transition",
                            d.policeVerified
                              ? "border-emerald-500/40 bg-emerald-500/10 text-emerald-500"
                              : "border-border text-muted-foreground hover:text-foreground",
                          )}
                        >
                          POLICE
                        </button>
                      </div>
                    </TableCell>
                    <TableCell className="text-xs text-muted-foreground">
                      {d._count?.rides ?? 0}
                    </TableCell>
                    <TableCell>
                      <span className="flex items-center gap-1 text-sm">
                        <Star className="h-3 w-3 text-yellow-500" />
                        {d.ratingAvg.toFixed(1)}
                      </span>
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-1">
                        {d.status === "PENDING" && (
                          <Button
                            size="sm"
                            variant="outline"
                            className="border-emerald-600/40 text-emerald-500"
                            onClick={() =>
                              setPending({ driver: d, action: "approve" })
                            }
                          >
                            <CheckCircle2 className="mr-1 h-3.5 w-3.5" /> Approve
                          </Button>
                        )}
                        {d.status === "ACTIVE" && (
                          <Button
                            size="sm"
                            variant="outline"
                            className="border-orange-500/40 text-orange-500"
                            onClick={() =>
                              setPending({ driver: d, action: "suspend" })
                            }
                          >
                            <ShieldAlert className="mr-1 h-3.5 w-3.5" /> Suspend
                          </Button>
                        )}
                        {d.status !== "BANNED" && (
                          <Button
                            size="sm"
                            variant="outline"
                            className="border-destructive/40 text-destructive"
                            onClick={() => setPending({ driver: d, action: "ban" })}
                          >
                            <ShieldX className="mr-1 h-3.5 w-3.5" /> Ban
                          </Button>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <Dialog open={!!pending} onOpenChange={(o) => !o && setPending(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{pending ? ACTION_LABELS[pending.action] : ""}</DialogTitle>
            <DialogDescription>
              {pending?.driver.name || "—"} •{" "}
              <span className="font-mono">{pending?.driver.phone}</span>
              {pending?.driver.rickshawNumber && (
                <> • 🚲 {pending.driver.rickshawNumber}</>
              )}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPending(null)} disabled={busy}>
              Cancel
            </Button>
            <Button
              onClick={confirmAction}
              disabled={busy}
              className={
                pending?.action === "ban" || pending?.action === "suspend"
                  ? "bg-destructive text-destructive-foreground hover:bg-destructive/90"
                  : ""
              }
            >
              {busy ? "Working…" : "Confirm"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
