import 'package:socket_io_client/socket_io_client.dart' as io;

/// Thin wrapper around socket.io-client that reads the current API base URL
/// from [ApiClient] and attaches the auth JWT as `auth.token` on connect.
///
/// One socket per session. Call [connect] once after login, [dispose] on logout.
///
/// Handlers registered via [on] are preserved across [connect] reconnects:
/// when [connect] disposes the previous socket and builds a new one, every
/// previously registered handler is re-bound to the new socket. This is
/// critical for the driver's "ride:offer" overlay, which calls [on] at app
/// startup — well before login — and must keep working after the user logs in
/// (which is when [connect] actually runs).
class RickboSocket {
  io.Socket? _socket;
  String? _baseUrl;
  String? _token;

  /// Persistent handler store. Keyed by event name, list of handlers
  /// (we keep a list in case the same event is registered from multiple
  /// places — e.g. both a screen widget and the OfferOverlayHost listen
  /// for 'ride:offer' on the user app).
  final Map<String, List<Function(dynamic)>> _handlers = {};

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
    // Re-bind all previously registered handlers to the new socket.
    _handlers.forEach((event, fns) {
      for (final fn in fns) {
        _socket!.on(event, fn);
      }
    });
    _socket!.connect();
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void on(String event, Function(dynamic) handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
    _socket?.on(event, handler);
  }

  void off(String event) {
    _handlers.remove(event);
    _socket?.off(event);
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    // NOTE: we deliberately keep _handlers so that a follow-up [connect] call
    // can re-bind them to the new socket. Call [disposeAll] if you want to
    // drop handlers too.
  }

  /// Drop the socket AND all registered handlers. Use only when you know you
  /// won't reconnect (e.g. on full logout where a brand-new RickboSocket will
  /// be constructed).
  void disposeAll() {
    dispose();
    _handlers.clear();
  }
}