import { Injectable } from '@nestjs/common';

export interface Zone {
  id: string;
  name: string;
  lat: number;
  lng: number;
  radius: number; // metres
}

export const ZONES: Zone[] = [
  { id: 'A', name: 'स्टेशन / बस अड्डा',       lat: 29.6039, lng: 78.3365, radius: 500 },
  { id: 'B', name: 'स्टेशन रोड / अस्पताल',    lat: 29.6089, lng: 78.3363, radius: 450 },
  { id: 'C', name: 'पुराना बाज़ार / तहसील',    lat: 29.6125, lng: 78.3406, radius: 450 },
  { id: 'D', name: 'नई तहसील / कोर्ट',         lat: 29.6081, lng: 78.3472, radius: 450 },
  { id: 'E', name: 'कोटद्वार रोड / सेंट मेरी', lat: 29.6105, lng: 78.3522, radius: 500 },
];

const shareTable: Record<string, Record<string, number>> = {
  A: { A: 10, B: 10, C: 10, D: 10, E: 15 },
  B: { A: 10, B: 10, C: 10, D: 10, E: 12 },
  C: { A: 10, B: 10, C: 10, D: 10, E: 10 },
  D: { A: 10, B: 10, C: 10, D: 10, E: 10 },
  E: { A: 15, B: 12, C: 10, D: 10, E: 10 },
};

const reserveTable: Record<string, Record<string, number>> = {
  A: { A: 20, B: 25, C: 25, D: 30, E: 35 },
  B: { A: 25, B: 20, C: 25, D: 25, E: 30 },
  C: { A: 25, B: 25, C: 20, D: 25, E: 25 },
  D: { A: 30, B: 25, C: 25, D: 20, E: 25 },
  E: { A: 35, B: 30, C: 25, D: 25, E: 20 },
};

@Injectable()
export class PricingService {
  getFare(from: string, to: string, mode: string, isNight: boolean): number {
    const table = mode === 'reserve' ? reserveTable : shareTable;
    const base = table[from]?.[to] ?? 10;
    return base + (isNight ? 5 : 0);
  }

  isNightNow(): boolean {
    const h = new Date().getHours();
    return h >= 21 || h < 6;
  }

  // Pick the closest zone center (we don't enforce radius for MVP — if the
  // GPS point is outside any radius, we still fall back to the nearest center).
  resolveZone(lat: number, lng: number): string {
    let nearest = ZONES[0];
    let minDist = Infinity;
    for (const z of ZONES) {
      const d = haversineKm(lat, lng, z.lat, z.lng);
      if (d < minDist) {
        minDist = d;
        nearest = z;
      }
    }
    return nearest.id;
  }
}

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toRad(deg: number) {
  return (deg * Math.PI) / 180;
}