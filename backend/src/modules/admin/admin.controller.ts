import {
  Controller, Post, Get, Body, Param, UseGuards, Query,
} from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminAuthGuard } from './admin-auth.guard';

@Controller('admin')
export class AdminController {
  constructor(private admin: AdminService) {}

  @Post('login')
  login(@Body() body: { username: string; password: string }) {
    return this.admin.login(body.username, body.password);
  }

  @UseGuards(AdminAuthGuard)
  @Get('stats')
  stats() {
    return this.admin.stats();
  }

  @UseGuards(AdminAuthGuard)
  @Get('rides')
  rides(@Query('limit') limit?: string, @Query('status') status?: string) {
    return this.admin.listRides({ limit: limit ? Number(limit) : 100, status });
  }

  @UseGuards(AdminAuthGuard)
  @Get('drivers')
  drivers(@Query('limit') limit?: string, @Query('status') status?: string) {
    return this.admin.listDrivers({ limit: limit ? Number(limit) : 200, status });
  }

  @UseGuards(AdminAuthGuard)
  @Get('users')
  users(@Query('limit') limit?: string) {
    return this.admin.listUsers(limit ? Number(limit) : 200);
  }

  @UseGuards(AdminAuthGuard)
  @Get('sos')
  sos(@Query('resolved') resolved?: string) {
    let r: boolean | undefined;
    if (resolved === 'true') r = true;
    else if (resolved === 'false') r = false;
    return this.admin.listSos({ resolved: r });
  }

  @UseGuards(AdminAuthGuard)
  @Post('sos/:id/resolve')
  resolveSos(@Param('id') id: string, @Body() body: { notes?: string }) {
    return this.admin.resolveSos(id, body?.notes);
  }

  @UseGuards(AdminAuthGuard)
  @Post('drivers/:id/ban')
  banDriver(@Param('id') id: string, @Body() body: { reason?: string }) {
    return this.admin.banDriver(id, body?.reason || 'banned by admin');
  }

  @UseGuards(AdminAuthGuard)
  @Post('drivers/:id/unban')
  unbanDriver(@Param('id') id: string) {
    return this.admin.unbanDriver(id);
  }

  @UseGuards(AdminAuthGuard)
  @Post('drivers/:id/suspend')
  suspendDriver(@Param('id') id: string) {
    return this.admin.suspendDriver(id);
  }

  @UseGuards(AdminAuthGuard)
  @Post('rides/:id/cancel')
  cancelRide(@Param('id') id: string) {
    return this.admin.cancelRide(id);
  }

  @UseGuards(AdminAuthGuard)
  @Get('complaints')
  complaints() {
    return this.admin.listComplaints();
  }

  @UseGuards(AdminAuthGuard)
  @Post('complaints/:id/resolve')
  resolveComplaint(@Param('id') id: string) {
    return this.admin.resolveComplaint(id);
  }
}