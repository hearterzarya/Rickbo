import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rickbo_core/rickbo_core.dart';

/// State for the admin session. Token only — the admin endpoints
/// don't need a profile cached client-side.
class AdminAuthState {
  final String? token;
  final String? phone;
  const AdminAuthState({this.token, this.phone});
  bool get isAuthed => token != null && token!.isNotEmpty;
}

class AdminAuthNotifier extends StateNotifier<AdminAuthState> {
  AdminAuthNotifier() : super(const AdminAuthState()) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await ApiClient().getToken();
    if (token != null && token.isNotEmpty) {
      state = AdminAuthState(token: token);
    }
  }

  Future<void> login(String token, String phone) async {
    await ApiClient().setToken(token);
    state = AdminAuthState(token: token, phone: phone);
  }

  Future<void> logout() async {
    await ApiClient().clearToken();
    state = const AdminAuthState();
  }
}

final authProvider = StateNotifierProvider<AdminAuthNotifier, AdminAuthState>(
  (ref) => AdminAuthNotifier(),
);