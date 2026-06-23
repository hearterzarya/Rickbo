class UserModel {
  final String id;
  final String phone;
  final String? name;
  final String? photoUrl;
  final String? fcmToken;
  final int trustScore;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  const UserModel({
    required this.id,
    required this.phone,
    this.name,
    this.photoUrl,
    this.fcmToken,
    this.trustScore = 0,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        phone: json['phone'] as String,
        name: json['name'] as String?,
        photoUrl: json['photoUrl'] as String?,
        fcmToken: json['fcmToken'] as String?,
        trustScore: (json['trustScore'] as num?)?.toInt() ?? 0,
        emergencyContactName: json['emergencyContactName'] as String?,
        emergencyContactPhone: json['emergencyContactPhone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        if (name != null) 'name': name,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (fcmToken != null) 'fcmToken': fcmToken,
        'trustScore': trustScore,
        if (emergencyContactName != null) 'emergencyContactName': emergencyContactName,
        if (emergencyContactPhone != null) 'emergencyContactPhone': emergencyContactPhone,
      };
}
