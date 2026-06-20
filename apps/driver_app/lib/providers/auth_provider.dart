import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rickbo_core/rickbo_core.dart';

class DriverAuthState {
  final String? token;
  final DriverModel? me;
  const DriverAuthState({this.token, this.me});
  bool get isAuthed => token != null && token!.isNotEmpty;
}

class DriverAuthNotifier extends StateNotifier<DriverAuthState> {
  DriverAuthNotifier() : super(const DriverAuthState()) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await ApiClient().getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final me = await RickboApi().getDriverMe();
        state = DriverAuthState(token: token, me: me);
      } catch (_) {
        await ApiClient().setToken('');
        state = const DriverAuthState();
      }
    }
  }

  void setAuthenticated(String token) {
    state = DriverAuthState(token: token);
  }

  void setProfile(DriverModel me) {
    state = DriverAuthState(token: state.token, me: me);
  }

  Future<void> logout() async {
    await ApiClient().setToken('');
    state = const DriverAuthState();
  }
}

final driverAuthProvider = StateNotifierProvider<DriverAuthNotifier, DriverAuthState>(
  (ref) => DriverAuthNotifier(),
);

/// Socket lifecycle tied to auth token.
final driverSocketProvider = Provider<RickboSocket>((ref) {
  final s = RickboSocket();
  ref.listen(driverAuthProvider, (prev, next) async {
    if (next.token != null) {
      final base = await ApiClient().getBaseUrl();
      await s.connect(baseUrl: base, token: next.token!);
      // Tell the server we exist.
      Future.delayed(const Duration(milliseconds: 300), () => s.emit('driver:online-init', {}));
    } else {
      s.dispose();
    }
  });
  ref.onDispose(s.dispose);
  return s;
});