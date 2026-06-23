-- Phase 3 Safety: store emergency contact on user profile so SOS can SMS a family/friend.
ALTER TABLE "User" ADD COLUMN "emergencyContactName" TEXT;
ALTER TABLE "User" ADD COLUMN "emergencyContactPhone" TEXT;
