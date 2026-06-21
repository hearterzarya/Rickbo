import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/users_list_screen.dart';
import '../screens/drivers_list_screen.dart';
import '../screens/rides_list_screen.dart';
import '../screens/sos_list_screen.dart';
import '../screens/zones_screen.dart';

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (ctx, state) {
      final authed = ref.read(authProvider).isAuthed;
      final goingToLogin = state.matchedLocation == '/login';
      if (!authed && !goingToLogin) return '/login';
      if (authed && goingToLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/users', builder: (_, __) => const UsersListScreen()),
      GoRoute(path: '/drivers', builder: (_, __) => const DriversListScreen()),
      GoRoute(path: '/rides', builder: (_, __) => const RidesListScreen()),
      GoRoute(path: '/sos', builder: (_, __) => const SosListScreen()),
      GoRoute(path: '/zones', builder: (_, __) => const ZonesScreen()),
    ],
  );
});