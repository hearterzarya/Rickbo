// Type definitions mirroring the NestJS /admin/* payloads.
// Kept hand-rolled (no Prisma codegen) so the admin stays decoupled
// from the backend build — the shape is the contract.

export type UserRole = "USER" | "ADMIN";

export type User = {
  id: string;
  phone: string;
  name: string | null;
  trustScore: number;
  isBanned: boolean;
  createdAt: string;
  _count?: { rides: number };
};

export type DriverStatus = "PENDING" | "ACTIVE" | "SUSPENDED" | "BANNED";

export type Driver = {
  id: string;
  phone: string;
  name: string | null;
  rickshawNumber: string | null;
  aadhaarVerified: boolean;
  policeVerified: boolean;
  status: DriverStatus;
  isOnline: boolean;
  ratingAvg: number;
  createdAt: string;
  _count?: { rides: number };
};

export type RideMode = "RESERVE" | "SHARE";
export type RideStatus =
  | "REQUESTED"
  | "MATCHED"
  | "ARRIVED"
  | "ONGOING"
  | "COMPLETED"
  | "CANCELLED";

export type Ride = {
  id: string;
  userId: string;
  driverId: string | null;
  mode: RideMode;
  fromZone: string;
  toZone: string;
  pickupLat: number;
  pickupLng: number;
  fare: number;
  passengerCount: number;
  status: RideStatus;
  requestedAt: string;
  startedAt: string | null;
  completedAt: string | null;
  user: { id: string; phone: string; name: string | null };
  driver: {
    id: string;
    phone: string;
    name: string | null;
    rickshawNumber: string | null;
  } | null;
};

export type SosRaisedBy = "USER" | "DRIVER";

export type SosEvent = {
  id: string;
  rideId: string;
  raisedBy: SosRaisedBy;
  lat: number;
  lng: number;
  createdAt: string;
  resolved: boolean;
  notes: string | null;
  ride: {
    id: string;
    user: { id: string; phone: string; name: string | null };
    driver: { id: string; phone: string; name: string | null } | null;
  };
};

export type Zone = {
  id: string;
  name: string;
  lat: number;
  lng: number;
  radius: number;
};

export type AdminStats = {
  users: number;
  drivers: number;
  activeDrivers: number;
  ridesToday: number;
  openSos: number;
  ongoingRides: number;
};

export type LoginResponse = {
  token: string;
  profile: { id: string; phone: string; role: UserRole; name: string | null };
  isNew: boolean;
};
