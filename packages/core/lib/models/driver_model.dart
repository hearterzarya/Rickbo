class DriverModel {
  final String id;
  final String phone;
  final String? name;
  final String? photoUrl;
  final String? rickshawNumber;
  final bool aadhaarVerified;
  final bool policeVerified;
  final String status;
  final bool isOnline;
  final double? locationLat;
  final double? locationLng;
  final double ratingAvg;
  final DateTime? subscriptionValidUntil;

  const DriverModel({
    required this.id,
    required this.phone,
    this.name,
    this.photoUrl,
    this.rickshawNumber,
    this.aadhaarVerified = false,
    this.policeVerified = false,
    this.status = 'PENDING',
    this.isOnline = false,
    this.locationLat,
    this.locationLng,
    this.ratingAvg = 0,
    this.subscriptionValidUntil,
  });

  /// True if the driver has a subscriptionValidUntil date and it has passed.
  /// Drivers with no subscription (legacy) are treated as active — matches the
  /// backend's findNearbyOnlineDrivers OR clause.
  bool get subscriptionExpired {
    final s = subscriptionValidUntil;
    if (s == null) return false;
    return s.isBefore(DateTime.now());
  }

  /// Whole days left in the subscription. Negative if expired. Null if no sub.
  int? get subscriptionDaysLeft {
    final s = subscriptionValidUntil;
    if (s == null) return null;
    final diff = s.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  factory DriverModel.fromJson(Map<String, dynamic> json) => DriverModel(
        id: json['id'] as String,
        phone: json['phone'] as String,
        name: json['name'] as String?,
        photoUrl: json['photoUrl'] as String?,
        rickshawNumber: json['rickshawNumber'] as String?,
        aadhaarVerified: json['aadhaarVerified'] as bool? ?? false,
        policeVerified: json['policeVerified'] as bool? ?? false,
        status: json['status'] as String? ?? 'PENDING',
        isOnline: json['isOnline'] as bool? ?? false,
        locationLat: (json['locationLat'] as num?)?.toDouble(),
        locationLng: (json['locationLng'] as num?)?.toDouble(),
        ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 0,
        subscriptionValidUntil: json['subscriptionValidUntil'] != null
            ? DateTime.tryParse(json['subscriptionValidUntil'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        if (name != null) 'name': name,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (rickshawNumber != null) 'rickshawNumber': rickshawNumber,
        'aadhaarVerified': aadhaarVerified,
        'policeVerified': policeVerified,
        'status': status,
        'isOnline': isOnline,
        if (locationLat != null) 'locationLat': locationLat,
        if (locationLng != null) 'locationLng': locationLng,
        'ratingAvg': ratingAvg,
        if (subscriptionValidUntil != null) 'subscriptionValidUntil': subscriptionValidUntil!.toIso8601String(),
      };
}
