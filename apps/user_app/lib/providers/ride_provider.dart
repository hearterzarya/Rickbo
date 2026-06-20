import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rickbo_core/rickbo_core.dart';

/// Holds the active ride the user is in. Created on POST /rides, mutated by
/// socket events (ride:matched, ride:arrived, ride:started, ride:completed,
/// ride:cancelled, ride:no-driver).
class ActiveRide {
  final String rideId;
  final String status;
  final int fare;
  final String? otp;
  final Map<String, dynamic>? driver;
  final double? pickupLat;
  final double? pickupLng;
  final double? driverLat;
  final double? driverLng;
  final String? fromZone;
  final String? toZone;
  final String? shareToken;
  final String cancelReason;

  const ActiveRide({
    required this.rideId,
    required this.status,
    required this.fare,
    this.otp,
    this.driver,
    this.pickupLat,
    this.pickupLng,
    this.driverLat,
    this.driverLng,
    this.fromZone,
    this.toZone,
    this.shareToken,
    this.cancelReason = '',
  });

  ActiveRide copyWith({
    String? status,
    int? fare,
    String? otp,
    Map<String, dynamic>? driver,
    double? driverLat,
    double? driverLng,
    String? cancelReason,
    String? shareToken,
  }) => ActiveRide(
        rideId: rideId,
        status: status ?? this.status,
        fare: fare ?? this.fare,
        otp: otp ?? this.otp,
        driver: driver ?? this.driver,
        pickupLat: pickupLat ?? this.pickupLng,
        pickupLng: pickupLng ?? this.pickupLng,
        driverLat: driverLat ?? this.driverLat,
        driverLng: driverLng ?? this.driverLng,
        fromZone: fromZone ?? this.fromZone,
        toZone: toZone ?? this.toZone,
        shareToken: shareToken ?? this.shareToken,
        cancelReason: cancelReason ?? this.cancelReason,
      );
}

class ActiveRideNotifier extends StateNotifier<ActiveRide?> {
  ActiveRideNotifier() : super(null);

  void start(ActiveRide ride) => state = ride;
  void update(ActiveRide Function(ActiveRide) fn) => state = state == null ? null : fn(state!);
  void clear() => state = null;
}

final activeRideProvider =
    StateNotifierProvider<ActiveRideNotifier, ActiveRide?>((ref) => ActiveRideNotifier());

/// One shared socket per session. Both the user and driver apps keep one.
final socketProvider = Provider<RickboSocket>((ref) {
  final s = RickboSocket();
  ref.onDispose(s.dispose);
  return s;
});
