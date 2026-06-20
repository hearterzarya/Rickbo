import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rickbo_core/rickbo_core.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/phone_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/ride/incoming_offer_screen.dart';
import 'screens/ride/ride_going_screen.dart';
import 'screens/ride/ride_otp_screen.dart';
import 'screens/ride/ride_finish_screen.dart';
import 'screens/ride/rate_user_screen.dart';
import 'screens/dev_settings_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Global listener that pops an "नई सवारी" overlay whenever the socket pushes
/// a `ride:offer` event, regardless of which screen the driver is on.
class OfferOverlayHost extends ConsumerStatefulWidget {
  final Widget child;
  const OfferOverlayHost({super.key, required this.child});

  @override
  ConsumerState<OfferOverlayHost> createState() => _OfferOverlayHostState();
}

class _OfferOverlayHostState extends ConsumerState<OfferOverlayHost> {
  late final RickboSocket _socket;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(driverSocketProvider);
    _socket.on('ride:offer', _handleOffer);
  }

  @override
  void dispose() {
    _socket.off('ride:offer');
    super.dispose();
  }

  Future<void> _handleOffer(dynamic data) async {
    if (_busy || data is! Map) return;
    _busy = true;
    try {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        await showDialog(
          context: ctx,
          barrierDismissible: false,
          builder: (dctx) => Dialog(
            backgroundColor: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                Navigator.pop(dctx);
                navigatorKey.currentState?.push(MaterialPageRoute(
                  builder: (_) => IncomingOfferScreen(
                    rideId: data['rideId'] as String,
                    fromZone: data['fromZone'] as String,
                    toZone: data['toZone'] as String,
                    fare: data['fare'] as int,
                    pickupLat: (data['pickupLat'] as num).toDouble(),
                    pickupLng: (data['pickupLng'] as num).toDouble(),
                    passengerCount: data['passengerCount'] as int? ?? 1,
                    userName: data['userName'] as String? ?? 'यात्री',
                  ),
                ));
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: blue,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: blue.withOpacity(0.5), blurRadius: 24)],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.directions_car, color: Colors.white, size: 56),
                  const SizedBox(height: 10),
                  Text('नई सवारी — ₹${data['fare']}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${data['fromZone']} → ${data['toZone']}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 16),
                  const Text('टैप करके खोलें', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
            ),
          ),
        );
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/splash',
    redirect: (ctx, st) {
      final auth = ref.read(driverAuthProvider);
      final loc = st.uri.toString();
      if (loc == '/splash') return null;
      if (!auth.isAuthed) {
        if (loc.startsWith('/auth/')) return null;
        return '/auth/phone';
      }
      if (loc.startsWith('/auth/')) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/auth/phone', builder: (_, __) => const PhoneScreen()),
      GoRoute(
        path: '/auth/otp',
        builder: (ctx, st) => OtpScreen(
          phone: st.extra is Map ? (st.extra as Map)['phone'] as String? ?? '' : '',
          devOtp: st.extra is Map ? (st.extra as Map)['devOtp'] as String? ?? '' : '',
        ),
      ),
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/ride/going',
        builder: (ctx, st) {
          final m = st.extra as Map;
          return RideGoingScreen(
            rideId: m['rideId'],
            fare: m['fare'],
            fromZone: m['fromZone'],
            toZone: m['toZone'],
            pickupLat: m['pickupLat'],
            pickupLng: m['pickupLng'],
            userName: m['userName'] ?? 'यात्री',
            passengerCount: m['passengerCount'] ?? 1,
          );
        },
      ),
      GoRoute(
        path: '/ride/otp',
        builder: (ctx, st) {
          final m = st.extra as Map;
          return RideOtpScreen(
            rideId: m['rideId'],
            fare: m['fare'],
            toZone: m['toZone'],
            userName: m['userName'] ?? 'यात्री',
          );
        },
      ),
      GoRoute(
        path: '/ride/finish',
        builder: (ctx, st) {
          final m = st.extra as Map;
          return RideFinishScreen(
            rideId: m['rideId'],
            fare: m['fare'],
            toZone: m['toZone'],
          );
        },
      ),
      GoRoute(
        path: '/ride/rate',
        builder: (ctx, st) {
          final m = st.extra as Map? ?? const {};
          return RateUserScreen(rideId: m['rideId'] as String);
        },
      ),
      GoRoute(path: '/dev-settings', builder: (_, __) => const DevSettingsScreen()),
    ],
  );
}