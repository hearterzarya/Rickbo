-- Phase 3/Admin: User role + ban flag
CREATE TYPE "UserRole" AS ENUM ('USER', 'ADMIN');
ALTER TABLE "User" ADD COLUMN "role" "UserRole" NOT NULL DEFAULT 'USER';
ALTER TABLE "User" ADD COLUMN "isBanned" BOOLEAN NOT NULL DEFAULT false;
CREATE INDEX "User_role_idx" ON "User"("role");
CREATE INDEX "User_isBanned_idx" ON "User"("isBanned");