import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rickbo_core/rickbo_core.dart';

/// Auth state — token is the source of truth.
class AuthState {
  final String? token;
  final bool? isNew;
  const AuthState({this.token, this.isNew});

  bool get isAuthed => token != null && token!.isNotEmpty;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await ApiClient().getToken();
    if (token != null && token.isNotEmpty) {
      state = AuthState(token: token, isNew: false);
    }
  }

  void setAuthenticated(String token, {required bool isNew}) {
    state = AuthState(token: token, isNew: isNew);
  }

  Future<void> logout() async {
    await ApiClient().setToken('');
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
