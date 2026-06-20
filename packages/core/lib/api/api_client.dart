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

  late Dio _dio;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_prefKeyBaseUrl) ?? _defaultBaseUrl;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
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

  Future<void> updateBaseUrl(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyBaseUrl, baseUrl);
    _dio.options.baseUrl = baseUrl;
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

  Dio get dio => _dio;
}
