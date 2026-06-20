import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/phone_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/booking/searching_screen.dart';
import 'screens/booking/driver_assigned_screen.dart';
import 'screens/booking/ride_in_progress_screen.dart';
import 'screens/booking/rate_ride_screen.dart';
import 'screens/dev_settings_screen.dart';

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (ctx, st) {
      final auth = ref.read(authProvider);
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
        builder: (ctx, st) {
          final extra = (st.extra is Map) ? st.extra as Map : const {};
          return OtpScreen(
            phone: extra['phone']?.toString() ?? '',
            devOtp: extra['devOtp']?.toString() ?? '',
            role: extra['role']?.toString() ?? 'user',
          );
        },
      ),
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/booking/searching',
        builder: (ctx, st) =>
            SearchingScreen(rideId: (st.extra as Map?)?['rideId']?.toString() ?? ''),
      ),
      GoRoute(
        path: '/booking/assigned',
        builder: (ctx, st) =>
            DriverAssignedScreen(rideId: (st.extra as Map?)?['rideId']?.toString() ?? ''),
      ),
      GoRoute(
        path: '/booking/ride',
        builder: (ctx, st) =>
            RideInProgressScreen(rideId: (st.extra as Map?)?['rideId']?.toString() ?? ''),
      ),
      GoRoute(
        path: '/booking/rate',
        builder: (ctx, st) =>
            RateRideScreen(rideId: (st.extra as Map?)?['rideId']?.toString() ?? ''),
      ),
      GoRoute(path: '/dev-settings', builder: (_, __) => const DevSettingsScreen()),
    ],
  );
}
