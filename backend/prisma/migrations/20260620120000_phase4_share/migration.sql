-- Phase 4: Share matching + driver subscription
-- Add share group fields to Ride
ALTER TABLE "Ride" ADD COLUMN "shareGroupId" TEXT;
ALTER TABLE "Ride" ADD COLUMN "shareDeadline" TIMESTAMP(3);
ALTER TABLE "Ride" ADD COLUMN "shareDetourM" INTEGER NOT NULL DEFAULT 800;
-- ShareFallback enum
CREATE TYPE "ShareFallback" AS ENUM ('SOLO', 'EXTEND', 'CANCEL');
ALTER TABLE "Ride" ADD COLUMN "shareFallback" "ShareFallback";
-- Index for fast group lookups during matching
CREATE INDEX "Ride_shareGroupId_idx" ON "Ride"("shareGroupId");
CREATE INDEX "Ride_status_shareGroupId_idx" ON "Ride"("status", "shareGroupId");
