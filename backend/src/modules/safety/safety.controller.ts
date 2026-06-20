import { Controller, Post, Body, UseGuards, Request } from '@nestjs/common';
import { SafetyService } from './safety.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { JwtPayload } from '../auth/jwt.strategy';

@Controller()
@UseGuards(JwtAuthGuard)
export class SafetyController {
  constructor(private safety: SafetyService) {}

  @Post('sos')
  sos(
    @Request() req: { user: JwtPayload },
    @Body() body: { rideId: string; lat: number; lng: number; notes?: string },
  ) {
    return this.safety.createSos({
      rideId: body.rideId,
      raisedBy: req.user.role === 'driver' ? 'DRIVER' : 'USER',
      lat: body.lat,
      lng: body.lng,
      notes: body.notes,
    });
  }

  @Post('ratings')
  rate(
    @Request() req: { user: JwtPayload },
    @Body() body: { rideId: string; stars: number; comment?: string },
  ) {
    return this.safety.createRating({
      rideId: body.rideId,
      by: req.user.sub,
      stars: body.stars,
      comment: body.comment,
    });
  }

  @Post('complaints')
  complain(
    @Request() req: { user: JwtPayload },
    @Body() body: { rideId: string; against: string; reason: string; severity?: number | string },
  ) {
    // Severity accepts "low" | "medium" | "high" (1|2|3) or numeric.
    let sev: number | undefined;
    if (typeof body.severity === 'number') sev = body.severity;
    else if (body.severity === 'low') sev = 1;
    else if (body.severity === 'medium') sev = 2;
    else if (body.severity === 'high') sev = 3;
    return this.safety.createComplaint({
      rideId: body.rideId,
      against: body.against,
      reason: body.reason,
      severity: sev,
    });
  }
}