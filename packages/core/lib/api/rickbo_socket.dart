import 'package:socket_io_client/socket_io_client.dart' as io;

/// Thin wrapper around socket.io-client that reads the current API base URL
/// from [ApiClient] and attaches the auth JWT as `auth.token` on connect.
///
/// One socket per session. Call [connect] once after login, [dispose] on logout.
class RickboSocket {
  io.Socket? _socket;
  String? _baseUrl;
  String? _token;

  io.Socket? get raw => _socket;
  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect({
    required String baseUrl,
    required String token,
  }) async {
    if (_socket != null && _baseUrl == baseUrl && _token == token && _socket!.connected) {
      return;
    }
    dispose();
    _baseUrl = baseUrl;
    _token = token;
    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket!.onConnectError((e) => /* ignore: avoid_print */ print('[ws] connect_error: $e'));
    _socket!.onError((e) => /* ignore: avoid_print */ print('[ws] error: $e'));
    _socket!.connect();
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}