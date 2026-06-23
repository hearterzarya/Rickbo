import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_client.dart';

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
  // Guards against concurrent connect() calls racing each other — without
  // this, a fast login→logout→login sequence (or two provider listeners
  // firing back-to-back) can build two sockets and leak one. P0-B5 fix.
  Future<void>? _connecting;

  /// Persistent handler store. Keyed by event name, list of handlers
  /// (we keep a list in case the same event is registered from multiple
  /// places — e.g. both a screen widget and the OfferOverlayHost listen
  /// for 'ride:offer' on the user app).
  final Map<String, List<Function(dynamic)>> _handlers = {};

  io.Socket? get raw => _socket;
  bool get isConnected => _socket?.connected ?? false;

  /// Warm up DNS cache so the subsequent socket connection doesn't hit
  /// errno=7 "No address associated with hostname" on cold app starts.
  Future<void> _warmUpDns() async {
    try {
      await ApiClient().dio.get('/pricing/zones').timeout(const Duration(seconds: 5));
    } catch (_) {
      // best-effort — if it fails, socket connect() will still try
    }
  }

  Future<void> connect({
    required String baseUrl,
    required String token,
  }) async {
    // Coalesce concurrent connect() calls — return the in-flight one if any.
    if (_connecting != null) {
      // ignore: avoid_print
      print('[ws] RickboSocket.connect: join in-flight connect');
      return _connecting!;
    }
    final completer = _connecting = _doConnect(baseUrl, token);
    try {
      await completer;
    } finally {
      _connecting = null;
    }
  }

  Future<void> _doConnect(String baseUrl, String token) async {
    // ignore: avoid_print
    print('[ws] RickboSocket.connect called baseUrl=$baseUrl tokenLen=${token.length}');
    if (_socket != null && _baseUrl == baseUrl && _token == token && _socket!.connected) {
      // ignore: avoid_print
      print('[ws] RickboSocket.connect: already connected, skip');
      return;
    }
    // Warm DNS before tearing down any existing socket
    await _warmUpDns();
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
    _socket!.onConnect((_) => /* ignore: avoid_print */ print('[ws] CONNECTED to $baseUrl'));
    _socket!.onDisconnect((reason) => /* ignore: avoid_print */ print('[ws] DISCONNECTED: $reason'));
    _socket!.onConnectError((e) => /* ignore: avoid_print */ print('[ws] connect_error: $e'));
    _socket!.onError((e) => /* ignore: avoid_print */ print('[ws] error: $e'));
    // Re-bind all previously registered handlers to the new socket.
    // ignore: avoid_print
    print('[ws] RickboSocket.connect: identityHash=${identityHashCode(this)}, _handlers keys BEFORE re-bind=${_handlers.keys.toList()}');
    _handlers.forEach((event, fns) {
      for (final fn in fns) {
        _socket!.on(event, fn);
      }
    });
    // ignore: avoid_print
    print('[ws] RickboSocket.connect: re-bound ${_handlers.length} event types, calling connect()');
    _socket!.connect();
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void on(String event, Function(dynamic) handler) {
    // ignore: avoid_print
    print('[ws] RickboSocket.on($event) called on identityHash=${identityHashCode(this)}, _handlers keys before=${_handlers.keys.toList()}');
    _handlers.putIfAbsent(event, () => []).add(handler);
    // ignore: avoid_print
    print('[ws] RickboSocket.on($event) after add, _handlers keys=${_handlers.keys.toList()}, count=${_handlers[event]!.length}');
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