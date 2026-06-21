import { Controller, Get, Post, Param, Body, UseGuards, Query } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminGuard } from './admin.guard';

@Controller('admin')
@UseGuards(AdminGuard)
export class AdminController {
  constructor(private admin: AdminService) {}

  // ─── Overview ─────────────────────────────────────────────────
  @Get('stats')
  stats() {
    return this.admin.stats();
  }

  // ─── Users ─────────────────────────────────────────────────────
  @Get('users')
  users() {
    return this.admin.listUsers();
  }

  @Post('users/:id/ban')
  banUser(@Param('id') id: string) {
    return this.admin.banUser(id);
  }

  @Post('users/:id/unban')
  unbanUser(@Param('id') id: string) {
    return this.admin.unbanUser(id);
  }

  // ─── Drivers ───────────────────────────────────────────────────
  @Get('drivers')
  drivers() {
    return this.admin.listDrivers();
  }

  @Post('drivers/:id/approve')
  approveDriver(@Param('id') id: string) {
    return this.admin.approveDriver(id);
  }

  @Post('drivers/:id/suspend')
  suspendDriver(@Param('id') id: string) {
    return this.admin.suspendDriver(id);
  }

  @Post('drivers/:id/ban')
  banDriver(@Param('id') id: string) {
    return this.admin.banDriver(id);
  }

  @Post('drivers/:id/verify-aadhaar')
  verifyAadhaar(@Param('id') id: string) {
    return this.admin.verifyDriver(id, 'aadhaar');
  }

  @Post('drivers/:id/verify-police')
  verifyPolice(@Param('id') id: string) {
    return this.admin.verifyDriver(id, 'police');
  }

  // ─── Rides ─────────────────────────────────────────────────────
  @Get('rides')
  rides(@Query('status') status?: string) {
    return this.admin.listRides(status);
  }

  @Post('rides/:id/cancel')
  cancelRide(@Param('id') id: string) {
    return this.admin.cancelRide(id);
  }

  // ─── SOS ───────────────────────────────────────────────────────
  @Get('sos')
  sos(@Query('resolved') resolved?: string) {
    let r: boolean | undefined;
    if (resolved === 'true') r = true;
    else if (resolved === 'false') r = false;
    return this.admin.listSos(r);
  }

  @Post('sos/:id/resolve')
  resolveSos(@Param('id') id: string, @Body() body: { notes?: string }) {
    return this.admin.resolveSos(id, body?.notes);
  }

  // ─── Zones (read-only) ────────────────────────────────────────
  @Get('zones')
  zones() {
    return this.admin.listZones();
  }
}