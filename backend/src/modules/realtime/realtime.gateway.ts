import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';

interface JwtPayload {
  sub: string;
  phone: string;
  role: 'user' | 'driver';
}

@WebSocketGateway({ cors: { origin: '*' }, namespace: '/' })
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  constructor(
    private jwt: JwtService,
    private config: ConfigService,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const token =
        (client.handshake.auth?.token as string | undefined) ??
        (client.handshake.headers['authorization'] as string | undefined)?.replace(/^Bearer /, '') ??
        (client.handshake.query?.token as string | undefined);

      if (!token) {
        // eslint-disable-next-line no-console
        console.log(`[ws] ${client.id} no token; disconnecting`);
        client.emit('auth:error', { message: 'token missing' });
        client.disconnect(true);
        return;
      }
      const payload = await this.jwt.verifyAsync<JwtPayload>(token, {
        secret: this.config.get<string>('JWT_SECRET') || 'dev-secret-change-in-prod',
      });
      const room = payload.role === 'driver' ? `driver:${payload.sub}` : `user:${payload.sub}`;
      client.join(room);
      (client.data as any).role = payload.role;
      (client.data as any).userId = payload.sub;
      client.emit('auth:ok', { role: payload.role });
      // eslint-disable-next-line no-console
      console.log(`[ws] ${client.id} authed as ${payload.role} ${payload.sub} (joined ${room})`);
    } catch (e: any) {
      // eslint-disable-next-line no-console
      console.log(`[ws] ${client.id} auth failed: ${e.message}`);
      client.emit('auth:error', { message: e.message });
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    // eslint-disable-next-line no-console
    console.log(`[ws] ${client.id} disconnected`);
  }

  // Driver pushes their current GPS — broadcast to user room if a ride is active.
  @SubscribeMessage('driver:location')
  location(
    @MessageBody() body: { rideId: string; lat: number; lng: number },
    @ConnectedSocket() client: Socket,
  ) {
    if (!body?.rideId) return;
    this.server.to(`ride:${body.rideId}`).emit('driver:location', {
      lat: body.lat,
      lng: body.lng,
      ts: Date.now(),
    });
  }

  // User joins the ride room so they receive driver:location + ride:status events.
  // Without this, the user's socket is in `user:${id}` only — it never sees ride-scoped events.
  @SubscribeMessage('ride:join')
  joinRideEvt(
    @MessageBody() body: { rideId: string },
    @ConnectedSocket() client: Socket,
  ) {
    if (!body?.rideId) return;
    client.join(`ride:${body.rideId}`);
    this.server.to(`ride:${body.rideId}`).emit('ride:joined', { rideId: body.rideId });
    // eslint-disable-next-line no-console
    console.log(`[ws] ${client.id} joined ride:${body.rideId}`);
  }

  // ---- Helpers used by other services (rides / matching / safety) ----
  emitToDriver(driverId: string, event: string, data: any) {
    this.server.to(`driver:${driverId}`).emit(event, data);
  }

  emitToUser(userId: string, event: string, data: any) {
    this.server.to(`user:${userId}`).emit(event, data);
  }

  joinRide(client: Socket, rideId: string) {
    client.join(`ride:${rideId}`);
  }

  emitToRide(rideId: string, event: string, data: any) {
    this.server.to(`ride:${rideId}`).emit(event, data);
  }
}