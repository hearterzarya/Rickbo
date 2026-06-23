"use client";

import useSWR from "swr";
import { MapPin, Map, RefreshCcw, CircleDot } from "lucide-react";
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
import { swrFetcher } from "@/lib/api";
import type { Zone } from "@/lib/types";

export default function ZonesPage() {
  const { data, isLoading, mutate } = useSWR<Zone[]>(
    "/admin/zones",
    swrFetcher,
    { refreshInterval: 60000 },
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Zones / क्षेत्र</h1>
          <p className="text-sm text-muted-foreground">
            Najibabad town — 5 fixed zones used for fare calculation
          </p>
        </div>
        <Button variant="outline" size="icon" onClick={() => mutate()}>
          <RefreshCcw className="h-4 w-4" />
        </Button>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
          <Skeleton className="h-40 w-full" />
          <Skeleton className="h-40 w-full" />
          <Skeleton className="h-40 w-full" />
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
          {data?.map((z) => (
            <Card key={z.id}>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <Badge
                    variant="outline"
                    className="h-9 w-9 justify-center text-lg font-bold"
                  >
                    {z.id}
                  </Badge>
                  <CircleDot className="h-5 w-5 text-primary" />
                </div>
                <CardTitle className="mt-2 text-lg">{z.name}</CardTitle>
                <CardDescription>Zone {z.id}</CardDescription>
              </CardHeader>
              <CardContent>
                <dl className="space-y-1.5 text-sm">
                  <div className="flex justify-between">
                    <dt className="text-muted-foreground">Latitude</dt>
                    <dd className="font-mono">{z.lat.toFixed(4)}</dd>
                  </div>
                  <div className="flex justify-between">
                    <dt className="text-muted-foreground">Longitude</dt>
                    <dd className="font-mono">{z.lng.toFixed(4)}</dd>
                  </div>
                  <div className="flex justify-between">
                    <dt className="text-muted-foreground">Radius</dt>
                    <dd className="font-mono">{z.radius} m</dd>
                  </div>
                </dl>
                <a
                  href={`https://www.openstreetmap.org/?mlat=${z.lat}&mlon=${z.lng}#map=17/${z.lat}/${z.lng}`}
                  target="_blank"
                  rel="noreferrer"
                  className="mt-3 inline-flex items-center gap-1 text-xs text-primary hover:underline"
                >
                  <MapPin className="h-3 w-3" /> Open in OSM →
                </a>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      <p className="text-xs text-muted-foreground">
        <Map className="mr-1 inline h-3 w-3" /> Zones are hard-coded in
        <code> backend/src/modules/pricing/pricing.service.ts</code> and mirrored in
        <code> packages/core/lib/zones.dart</code>. Same data drives the Flutter apps.
      </p>
    </div>
  );
}
