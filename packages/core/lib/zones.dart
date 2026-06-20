import 'dart:math';

const List<Map<String, dynamic>> zones = [
  {'id': 'A', 'name': 'स्टेशन / बस अड्डा',       'lat': 29.6039, 'lng': 78.3365, 'radius': 500},
  {'id': 'B', 'name': 'स्टेशन रोड / अस्पताल',    'lat': 29.6089, 'lng': 78.3363, 'radius': 450},
  {'id': 'C', 'name': 'पुराना बाज़ार / तहसील',    'lat': 29.6125, 'lng': 78.3406, 'radius': 450},
  {'id': 'D', 'name': 'नई तहसील / कोर्ट',         'lat': 29.6081, 'lng': 78.3472, 'radius': 450},
  {'id': 'E', 'name': 'कोटद्वार रोड / सेंट मेरी', 'lat': 29.6105, 'lng': 78.3522, 'radius': 500},
];

String zoneNameById(String id) =>
    zones.firstWhere((z) => z['id'] == id, orElse: () => zones.first)['name'] as String;

/// Returns the nearest zone id for the given lat/lng.
/// If outside all radii, returns the geographically closest zone center.
String resolveZone(double lat, double lng) {
  String nearestId = zones.first['id'] as String;
  double nearestDist = double.infinity;
  for (final z in zones) {
    final d = _distanceMeters(lat, lng, z['lat'] as double, z['lng'] as double);
    if (d < nearestDist) {
      nearestDist = d;
      nearestId = z['id'] as String;
    }
  }
  return nearestId;
}

double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _rad(double deg) => deg * pi / 180;
