import 'api_client.dart';
import '../models/ride_model.dart';
import '../models/driver_model.dart';
import '../models/user_model.dart';

/// Lightweight façade over [ApiClient] for type-safe call sites.
class RickboApi {
  final ApiClient _c = ApiClient();

  Future<Map<String, dynamic>> startTestOtp({required String phone, required String role}) async {
    final r = await _c.dio.post('/auth/test-otp/start', data: {'phone': phone, 'role': role});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyTestOtp({
    required String phone,
    required String otp,
    required String role,
  }) async {
    final r = await _c.dio.post(
      '/auth/test-otp/verify',
      data: {'phone': phone, 'otp': otp, 'role': role},
    );
    return r.data as Map<String, dynamic>;
  }

  /// ONE-CALL dev login: returns the full login payload (token + user/driver)
  /// in a single round-trip. Backend auto-creates the profile if missing.
  /// Used by the in-app "टेस्ट लॉगिन" button on the phone screen so the
  /// emulator can land on home without swapping screens and pasting an OTP.
  Future<Map<String, dynamic>> loginTestOtp({
    required String phone,
    required String role,
  }) async {
    final r = await _c.dio.post(
      '/auth/test-otp',
      data: {'phone': phone, 'role': role},
    );
    return r.data as Map<String, dynamic>;
  }

  Future<UserModel> getUserMe() async {
    final r = await _c.dio.get('/users/me');
    return UserModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<UserModel> updateUserMe({String? name, String? fcmToken}) async {
    final r = await _c.dio.patch('/users/me', data: {
      if (name != null) 'name': name,
      if (fcmToken != null) 'fcmToken': fcmToken,
    });
    return UserModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<DriverModel> getDriverMe() async {
    final r = await _c.dio.get('/drivers/me');
    return DriverModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<DriverModel> updateDriverMe({String? name, String? rickshawNumber}) async {
    final r = await _c.dio.patch('/drivers/me', data: {
      if (name != null) 'name': name,
      if (rickshawNumber != null) 'rickshawNumber': rickshawNumber,
    });
    return DriverModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<DriverModel> updateDriverLocation(double lat, double lng) async {
    final r = await _c.dio.post('/drivers/me/location', data: {'lat': lat, 'lng': lng});
    return DriverModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<DriverModel> goOnline() async {
    final r = await _c.dio.post('/drivers/me/online');
    return DriverModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<DriverModel> goOffline() async {
    final r = await _c.dio.post('/drivers/me/offline');
    return DriverModel.fromJson(r.data as Map<String, dynamic>);
  }

  // Phase 2.5+ — driver home screen ke liye आज/हफ्ता/महीने का stats।
  Future<Map<String, dynamic>> getDriverStats({String period = 'today'}) async {
    final r = await _c.dio.get('/drivers/me/stats', queryParameters: {'period': period});
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getZones() async {
    final r = await _c.dio.get('/pricing/zones');
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  Future<RideModel> createRide({
    required String mode,
    required String fromZone,
    required String toZone,
    required double pickupLat,
    required double pickupLng,
    int passengerCount = 1,
  }) async {
    final r = await _c.dio.post('/rides', data: {
      'mode': mode,
      'fromZone': fromZone,
      'toZone': toZone,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'passengerCount': passengerCount,
    });
    return RideModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<RideModel> acceptRide(String rideId) async {
    final r = await _c.dio.post('/rides/$rideId/accept');
    return RideModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<RideModel> arriveRide(String rideId) async {
    final r = await _c.dio.post('/rides/$rideId/arrive');
    return RideModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<RideModel> startRide(String rideId, String otp) async {
    final r = await _c.dio.post('/rides/$rideId/start', data: {'otp': otp});
    return RideModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<RideModel> completeRide(String rideId) async {
    final r = await _c.dio.post('/rides/$rideId/complete');
    return RideModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<RideModel> cancelRide(String rideId, {String? reason}) async {
    final r = await _c.dio.post('/rides/$rideId/cancel', data: {if (reason != null) 'reason': reason});
    return RideModel.fromJson(r.data as Map<String, dynamic>);
  }

  // Phase 4: share fallback action (SOLO / EXTEND / CANCEL)
  Future<RideModel> shareAction(String rideId, String action) async {
    final r = await _c.dio.post('/rides/$rideId/share-action', data: {'action': action});
    return RideModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> raiseSos({required String rideId, required double lat, required double lng}) async {
    await _c.dio.post('/sos', data: {'rideId': rideId, 'lat': lat, 'lng': lng});
  }

  Future<void> rateRide({required String rideId, required int stars, String? comment}) async {
    await _c.dio.post('/ratings', data: {'rideId': rideId, 'stars': stars, if (comment != null) 'comment': comment});
  }

  // ─── Phase 3: complaints + share links ─────────────────────────────────────
  Future<void> raiseComplaint({
    required String rideId,
    required String against,
    required String reason,
    int severity = 1,
  }) async {
    await _c.dio.post('/complaints', data: {
      'rideId': rideId,
      'against': against,
      'reason': reason,
      'severity': severity,
    });
  }

  // The share URL is built from the backend's PUBLIC hostname + share token.
  // Backend now returns shareToken on the ride object; the apps stitch the URL together.
  String buildShareUrl({required String baseUrl, required String shareToken}) {
    final root = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$root/s/$shareToken';
  }

  // ─── Friendly aliases used by the driver app screens ─────────────────────
  Future<DriverModel> postLocation(double lat, double lng) =>
      updateDriverLocation(lat, lng);

  /// Decline a ride offer = cancel from the driver side while still REQUESTED.
  Future<RideModel> declineRide(String rideId, {String? reason}) =>
      cancelRide(rideId, reason: reason ?? 'driver_declined');

  Future<RideModel> markArrived(String rideId) => arriveRide(rideId);
}