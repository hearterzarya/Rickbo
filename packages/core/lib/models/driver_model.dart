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
  });

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
      };
}
