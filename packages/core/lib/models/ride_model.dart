class RideModel {
  final String id;
  final String userId;
  final String? driverId;
  final String mode; // 'RESERVE' | 'SHARE'
  final String fromZone;
  final String toZone;
  final double pickupLat;
  final double pickupLng;
  final int fare;
  final int passengerCount;
  final String status;
  final String? otp;
  final String? shareToken;
  final String? shareGroupId;
  final DateTime? shareDeadline;
  final String? shareFallback;

  const RideModel({
    required this.id,
    required this.userId,
    this.driverId,
    required this.mode,
    required this.fromZone,
    required this.toZone,
    required this.pickupLat,
    required this.pickupLng,
    required this.fare,
    this.passengerCount = 1,
    this.status = 'REQUESTED',
    this.otp,
    this.shareToken,
    this.shareGroupId,
    this.shareDeadline,
    this.shareFallback,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) => RideModel(
        id: json['id'] as String,
        userId: json['userId'] as String,
        driverId: json['driverId'] as String?,
        mode: json['mode'] as String,
        fromZone: json['fromZone'] as String,
        toZone: json['toZone'] as String,
        pickupLat: (json['pickupLat'] as num).toDouble(),
        pickupLng: (json['pickupLng'] as num).toDouble(),
        fare: (json['fare'] as num).toInt(),
        passengerCount: (json['passengerCount'] as num?)?.toInt() ?? 1,
        status: json['status'] as String? ?? 'REQUESTED',
        otp: json['otp'] as String?,
        shareToken: json['shareToken'] as String?,
        shareGroupId: json['shareGroupId'] as String?,
        shareDeadline: json['shareDeadline'] != null
            ? DateTime.tryParse(json['shareDeadline'] as String)
            : null,
        shareFallback: json['shareFallback'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        if (driverId != null) 'driverId': driverId,
        'mode': mode,
        'fromZone': fromZone,
        'toZone': toZone,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'fare': fare,
        'passengerCount': passengerCount,
        'status': status,
        if (otp != null) 'otp': otp,
        if (shareToken != null) 'shareToken': shareToken,
        if (shareGroupId != null) 'shareGroupId': shareGroupId,
        if (shareDeadline != null) 'shareDeadline': shareDeadline!.toIso8601String(),
        if (shareFallback != null) 'shareFallback': shareFallback,
      };

  /// Seconds remaining in the SHARE 2-min window (or null if not a SHARE ride / window passed).
  int? get shareSecondsRemaining {
    if (shareDeadline == null) return null;
    final diff = shareDeadline!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }
}