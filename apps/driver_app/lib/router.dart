import 'dart:async';
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
import 'screens/ride/ride_ongoing_screen.dart';
import 'screens/ride/ride_finish_screen.dart';
import 'screens/subscription_screen.dart';
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
  bool _wired = false;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(driverSocketProvider);
    // Re-wire listener whenever a fresh socket appears (RickboSocket.connect
    // disposes the previous socket, so any handlers registered on the old one
    // are lost). We re-register after every login / reconnect.
    _socket.on('ride:offer', _handleOffer);
    _wired = true;
  }

  @override
  void dispose() {
    if (_wired) _socket.off('ride:offer');
    super.dispose();
  }

  Future<void> _handleOffer(dynamic data) async {
    if (_busy || data is! Map) return;
    _busy = true;
    try {
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      // Triple-alert: vibration + sound + TTS. Doesn't await — fires in parallel
      // and doesn't block the dialog from showing.
      final fromZone = data['fromZone'] as String? ?? '';
      final toZone = data['toZone'] as String? ?? '';
      final fare = (data['fare'] as num?)?.toInt() ?? 0;
      unawaited(RideAlert.urgent('सवारी है $fromZone से $toZone, $fare रुपये'));
      await showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (dctx) => _PulsingOfferDialog(
          data: data,
          onAccept: () {
            Navigator.pop(dctx);
            navigatorKey.currentState?.push(MaterialPageRoute(
              builder: (_) => IncomingOfferScreen(
                rideId: data['rideId'] as String,
                fromZone: fromZone,
                toZone: toZone,
                fare: fare,
                pickupLat: (data['pickupLat'] as num).toDouble(),
                pickupLng: (data['pickupLng'] as num).toDouble(),
                passengerCount: data['passengerCount'] as int? ?? 1,
                userName: data['userName'] as String? ?? 'यात्री',
              ),
            ));
          },
        ),
      );
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
            rideId: m['rideId'] as String,
            fare: (m['fare'] as num).toInt(),
            fromZone: m['fromZone']?.toString() ?? '',
            toZone: m['toZone']?.toString() ?? '',
            pickupLat: (m['pickupLat'] as num).toDouble(),
            pickupLng: (m['pickupLng'] as num).toDouble(),
            userName: m['userName']?.toString() ?? 'यात्री',
            passengerCount: (m['passengerCount'] as num?)?.toInt() ?? 1,
          );
        },
      ),
      GoRoute(
        path: '/ride/ongoing',
        builder: (ctx, st) {
          final m = st.extra as Map;
          return RideOngoingScreen(
            rideId: m['rideId'],
            fare: m['fare'],
            fromZone: m['fromZone'] ?? '',
            toZone: m['toZone'] ?? '',
            pickupLat: (m['pickupLat'] as num).toDouble(),
            pickupLng: (m['pickupLng'] as num).toDouble(),
            userName: m['userName'] ?? 'यात्री',
            passengerCount: (m['passengerCount'] as num?)?.toInt() ?? 1,
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
      GoRoute(path: '/subscription', builder: (_, __) => const SubscriptionScreen()),
    ],
  );
}

/// Animated "नई सवारी" offer popup with a pulsing blue glow border.
/// The whole card pulses to grab the driver's attention even when they're
/// not looking directly at the screen. Tap → opens the full IncomingOfferScreen
/// with हाँ / ना buttons (20s auto-decline countdown starts there).
class _PulsingOfferDialog extends StatefulWidget {
  final Map data;
  final VoidCallback onAccept;
  const _PulsingOfferDialog({required this.data, required this.onAccept});

  @override
  State<_PulsingOfferDialog> createState() => _PulsingOfferDialogState();
}

class _PulsingOfferDialogState extends State<_PulsingOfferDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fromZone = widget.data['fromZone'] as String? ?? '';
    final toZone = widget.data['toZone'] as String? ?? '';
    final fare = (widget.data['fare'] as num?)?.toInt() ?? 0;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GestureDetector(
        onTap: widget.onAccept,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: blue,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.4 + 0.6 * _c.value),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: blue.withOpacity(0.4 + 0.5 * _c.value),
                  blurRadius: 30 + 20 * _c.value,
                  spreadRadius: 4 + 6 * _c.value,
                ),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Big pulsing rickshaw icon.
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15 + 0.15 * _c.value),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.electric_rickshaw,
                    color: Colors.white, size: 64),
              ),
              const SizedBox(height: 14),
              const Text(
                'नई सवारी!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₹$fare',
                  style: const TextStyle(
                    color: blue,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '$fromZone  →  $toZone',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'टैप करके खोलें',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}