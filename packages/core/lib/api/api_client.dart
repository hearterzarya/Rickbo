import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKeyBaseUrl = 'api_base_url';
const _prefKeyToken = 'auth_token';

// Default: deployed Rickbo backend on Railway. Local dev builds can switch via the Dev Settings screen.
const _defaultBaseUrl = 'https://rickbo-production.up.railway.app';

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  Dio? _dio;
  Future<void>? _initFuture;

  /// Initialize the Dio instance. Safe to call multiple times — subsequent
  /// calls return the same in-flight future. We also auto-init lazily on
  /// first `.dio` access, so callers that forget to call init() still work.
  Future<void> init() {
    return _initFuture ??= _doInit();
  }

  Future<void> _doInit() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_prefKeyBaseUrl) ?? _defaultBaseUrl;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final p = await SharedPreferences.getInstance();
        final token = p.getString(_prefKeyToken);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (err, handler) {
        // Swallow network errors here; callers handle them
        handler.next(err);
      },
    ));
  }

  /// Returns the Dio instance, lazily initializing on first access.
  /// If init() hasn't been awaited yet, this waits for it.
  Future<Dio> getDio() async {
    if (_dio == null) await init();
    return _dio!;
  }

  /// Synchronous access — only safe AFTER init() has been awaited.
  /// Most call sites use this through `await ApiClient().getDio()` instead.
  Dio get dio {
    final d = _dio;
    if (d == null) {
      throw StateError(
        'ApiClient not initialized — call `await ApiClient().init()` '
        'in main() before using .dio. Or use `await ApiClient().getDio()`.',
      );
    }
    return d;
  }

  Future<void> updateBaseUrl(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyBaseUrl, baseUrl);
    // If dio is not built yet, the next init() will pick up the new URL.
    _dio?.options.baseUrl = baseUrl;
  }

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyBaseUrl) ?? _defaultBaseUrl;
  }

  /// Friendly alias used by the driver app dev-settings screen.
  Future<void> setBaseUrl(String baseUrl) => updateBaseUrl(baseUrl);

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyToken, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyToken);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyToken);
  }
}
