"use client";

import { useState } from "react";
import useSWR from "swr";
import { toast } from "sonner";
import { Ban, ShieldCheck, Search, RefreshCcw, Star } from "lucide-react";
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
import { formatDate, maskPhone } from "@/lib/utils";
import type { User } from "@/lib/types";

export default function UsersPage() {
  const { data, mutate, isLoading } = useSWR<User[]>(
    "/admin/users",
    swrFetcher,
    { refreshInterval: 15000 },
  );
  const [search, setSearch] = useState("");
  const [pending, setPending] = useState<{ user: User; action: "ban" | "unban" } | null>(
    null,
  );
  const [busy, setBusy] = useState(false);

  const filtered =
    data?.filter(
      (u) =>
        u.phone.includes(search) ||
        (u.name ?? "").toLowerCase().includes(search.toLowerCase()),
    ) ?? [];

  async function confirmAction() {
    if (!pending) return;
    setBusy(true);
    try {
      const { user, action } = pending;
      const path = `/admin/users/${user.id}/${action}`;
      await api.post(path);
      toast.success(`User ${action}ed: ${user.phone}`);
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
          <h1 className="text-3xl font-bold tracking-tight">Users / यात्री</h1>
          <p className="text-sm text-muted-foreground">
            Passengers who signed up via the Rickbo user app
          </p>
        </div>
        <div className="flex gap-2">
          <div className="relative">
            <Search className="absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search phone or name…"
              className="pl-8 w-64"
            />
          </div>
          <Button variant="outline" size="icon" onClick={() => mutate()}>
            <RefreshCcw className="h-4 w-4" />
          </Button>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>All users</CardTitle>
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
              कोई यात्री नहीं मिला — No users found
            </p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name / नाम</TableHead>
                  <TableHead>Phone / फ़ोन</TableHead>
                  <TableHead>Rides / सवारी</TableHead>
                  <TableHead>Trust / भरोसा</TableHead>
                  <TableHead>Joined / जुड़े</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Action</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filtered.map((u) => (
                  <TableRow key={u.id}>
                    <TableCell className="font-medium">{u.name || "—"}</TableCell>
                    <TableCell className="font-mono text-xs">
                      {maskPhone(u.phone)}
                    </TableCell>
                    <TableCell>{u._count?.rides ?? 0}</TableCell>
                    <TableCell>
                      <span className="flex items-center gap-1 text-sm">
                        <Star className="h-3 w-3 text-yellow-500" />
                        {u.trustScore}
                      </span>
                    </TableCell>
                    <TableCell className="text-xs text-muted-foreground">
                      {formatDate(u.createdAt)}
                    </TableCell>
                    <TableCell>
                      {u.isBanned ? (
                        <Badge variant="destructive">Banned</Badge>
                      ) : (
                        <Badge variant="secondary">Active</Badge>
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      {u.isBanned ? (
                        <Button
                          size="sm"
                          variant="outline"
                          className="border-emerald-600/40 text-emerald-500"
                          onClick={() => setPending({ user: u, action: "unban" })}
                        >
                          <ShieldCheck className="mr-1 h-3.5 w-3.5" /> Unban
                        </Button>
                      ) : (
                        <Button
                          size="sm"
                          variant="outline"
                          className="border-destructive/40 text-destructive"
                          onClick={() => setPending({ user: u, action: "ban" })}
                        >
                          <Ban className="mr-1 h-3.5 w-3.5" /> Ban
                        </Button>
                      )}
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
            <DialogTitle>
              {pending?.action === "ban" ? "Ban this user?" : "Unban this user?"}
            </DialogTitle>
            <DialogDescription>
              {pending?.user.name || "—"} •{" "}
              <span className="font-mono">{pending?.user.phone}</span>
              <br />
              {pending?.action === "ban"
                ? "Banned users cannot book rides. You can reverse this later."
                : "They will be able to book rides again."}
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
                pending?.action === "ban"
                  ? "bg-destructive text-destructive-foreground hover:bg-destructive/90"
                  : ""
              }
            >
              {busy ? "Working…" : pending?.action === "ban" ? "Ban user" : "Unban user"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
