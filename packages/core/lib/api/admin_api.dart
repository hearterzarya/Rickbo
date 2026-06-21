import 'api_client.dart';

/// Admin API client. Reuses the same Dio instance + auth header
/// from [ApiClient] so any JWT (with role=admin) gets passed
/// automatically on every call.
class AdminApi {
  final ApiClient _c = ApiClient();

  Map<String, dynamic> _q(Map<String, dynamic> r) => (r is Map) ? r.cast<String, dynamic>() : <String, dynamic>{};
  List<Map<String, dynamic>> _l(dynamic r) => r is List ? r.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];

  Future<Map<String, dynamic>> stats() async {
    final r = await _c.dio.get('/admin/stats');
    return _q(r.data);
  }

  Future<List<Map<String, dynamic>>> users() async {
    final r = await _c.dio.get('/admin/users');
    return _l(r.data);
  }

  Future<Map<String, dynamic>> banUser(String id) async {
    final r = await _c.dio.post('/admin/users/$id/ban');
    return _q(r.data);
  }

  Future<Map<String, dynamic>> unbanUser(String id) async {
    final r = await _c.dio.post('/admin/users/$id/unban');
    return _q(r.data);
  }

  Future<List<Map<String, dynamic>>> drivers() async {
    final r = await _c.dio.get('/admin/drivers');
    return _l(r.data);
  }

  Future<Map<String, dynamic>> approveDriver(String id) async {
    final r = await _c.dio.post('/admin/drivers/$id/approve');
    return _q(r.data);
  }

  Future<Map<String, dynamic>> suspendDriver(String id) async {
    final r = await _c.dio.post('/admin/drivers/$id/suspend');
    return _q(r.data);
  }

  Future<Map<String, dynamic>> banDriver(String id) async {
    final r = await _c.dio.post('/admin/drivers/$id/ban');
    return _q(r.data);
  }

  Future<Map<String, dynamic>> verifyAadhaar(String id) async {
    final r = await _c.dio.post('/admin/drivers/$id/verify-aadhaar');
    return _q(r.data);
  }

  Future<Map<String, dynamic>> verifyPolice(String id) async {
    final r = await _c.dio.post('/admin/drivers/$id/verify-police');
    return _q(r.data);
  }

  Future<List<Map<String, dynamic>>> rides({String? status}) async {
    final r = await _c.dio.get('/admin/rides', queryParameters: status != null ? {'status': status} : null);
    return _l(r.data);
  }

  Future<Map<String, dynamic>> cancelRide(String id) async {
    final r = await _c.dio.post('/admin/rides/$id/cancel');
    return _q(r.data);
  }

  Future<List<Map<String, dynamic>>> sos({bool? resolved}) async {
    final qp = resolved == null ? null : {'resolved': resolved.toString()};
    final r = await _c.dio.get('/admin/sos', queryParameters: qp);
    return _l(r.data);
  }

  Future<Map<String, dynamic>> resolveSos(String id, {String? notes}) async {
    final r = await _c.dio.post('/admin/sos/$id/resolve', data: {if (notes != null) 'notes': notes});
    return _q(r.data);
  }

  Future<List<Map<String, dynamic>>> zones() async {
    final r = await _c.dio.get('/admin/zones');
    return _l(r.data);
  }
}