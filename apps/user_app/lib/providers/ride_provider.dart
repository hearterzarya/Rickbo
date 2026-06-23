import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rickbo_core/rickbo_core.dart';
import 'auth_provider.dart';

/// Holds the active ride the user is in. Created on POST /rides, mutated by
/// socket events (ride:matched, ride:arrived, ride:started, ride:completed,
/// ride:cancelled, ride:no-driver).
class ActiveRide {
  final String rideId;
  final String status;
  final String mode; // 'RESERVE' | 'SHARE'
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
  final String? shareGroupId;
  final DateTime? shareDeadline;
  final String cancelReason;

  const ActiveRide({
    required this.rideId,
    required this.status,
    this.mode = 'RESERVE',
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
    this.shareGroupId,
    this.shareDeadline,
    this.cancelReason = '',
  });

  ActiveRide copyWith({
    String? status,
    String? mode,
    int? fare,
    String? otp,
    Map<String, dynamic>? driver,
    double? pickupLat,
    double? pickupLng,
    double? driverLat,
    double? driverLng,
    String? fromZone,
    String? toZone,
    String? cancelReason,
    String? shareToken,
    String? shareGroupId,
    DateTime? shareDeadline,
  }) => ActiveRide(
        rideId: rideId,
        status: status ?? this.status,
        mode: mode ?? this.mode,
        fare: fare ?? this.fare,
        otp: otp ?? this.otp,
        driver: driver ?? this.driver,
        pickupLat: pickupLat ?? this.pickupLat,
        pickupLng: pickupLng ?? this.pickupLng,
        driverLat: driverLat ?? this.driverLat,
        driverLng: driverLng ?? this.driverLng,
        fromZone: fromZone ?? this.fromZone,
        toZone: toZone ?? this.toZone,
        shareToken: shareToken ?? this.shareToken,
        shareGroupId: shareGroupId ?? this.shareGroupId,
        shareDeadline: shareDeadline ?? this.shareDeadline,
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
/// Lifecycle is tied to the auth token: when the user logs in we connect;
/// on logout we tear down. ref.onDispose also kills the inner socket but
/// keeps the registered handler list so the next login re-binds.
final socketProvider = Provider<RickboSocket>((ref) {
  final s = RickboSocket();
  ref.listen(authProvider, (prev, next) async {
    if (next.token != null && next.token!.isNotEmpty) {
      try {
        final base = await ApiClient().getBaseUrl();
        await s.connect(baseUrl: base, token: next.token!);
      } catch (_) {
        // best-effort — screens will retry via their own state changes
      }
    } else {
      s.disposeAll();
    }
  });
  ref.onDispose(s.disposeAll);
  return s;
});
