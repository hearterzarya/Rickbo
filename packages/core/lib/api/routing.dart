import 'dart:async';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// One leg of a road route: ordered polyline + total distance/duration.
class RoadRoute {
  final List<LatLng> points;
  final double meters;
  final double seconds;
  final List<Maneuver> maneuvers;

  const RoadRoute({
    required this.points,
    required this.meters,
    required this.seconds,
    this.maneuvers = const [],
  });
}

/// A single OSRM step maneuver (e.g. "turn right", "continue straight").
/// [location] is the lat/lng where the maneuver happens.
/// [distanceFromStart] is meters from the start of the leg to that point —
/// used to figure out which maneuver is "next" given the driver's position.
class Maneuver {
  final String type; // 'turn' | 'new name' | 'depart' | 'arrive' | 'merge' | ...
  final String modifier; // 'left' | 'right' | 'straight' | 'uturn' | ...
  final LatLng location;
  final double distanceFromStart; // meters
  final int index; // index of [RoadRoute.points] closest to this maneuver

  const Maneuver({
    required this.type,
    required this.modifier,
    required this.location,
    required this.distanceFromStart,
    required this.index,
  });
}

/// Free public OSRM demo server. Works for Najibabad coords. If this becomes
/// slow in production, self-host OSRM and override [baseUrl] in the call site.
const _osrmBase = 'https://router.project-osrm.org';

/// Caches routes between the same two endpoints for 60 s so we don't hammer
/// OSRM while the driver jitters a few meters every refresh.
final Map<String, _CacheEntry> _routeCache = {};

class _CacheEntry {
  final RoadRoute route;
  final DateTime at;
  _CacheEntry(this.route) : at = DateTime.now();
}

class Routing {
  Routing._();

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 8),
  ));

  /// Fetch a driving route from `from` → `to` via OSRM.
  ///
  /// OSRM coordinates are `lng,lat` (note the order). Coordinates parameter
  /// is `lat,lng` because that's how Rickbo stores them everywhere — we flip
  /// internally so the call sites stay consistent.
  ///
  /// Returns `null` on any failure (no network, no road, OSRM down) so the
  /// caller can fall back to a straight line.
  static Future<RoadRoute?> roadRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final key = '$fromLat,$fromLng->$toLat,$toLng';
    final cached = _routeCache[key];
    if (cached != null && DateTime.now().difference(cached.at).inSeconds < 60) {
      return cached.route;
    }
    try {
      final url = '$_osrmBase/route/v1/driving/'
          '$fromLng,$fromLat;$toLng,$toLat'
          '?overview=full&geometries=geojson&steps=true';
      final r = await _dio.get(url);
      if (r.statusCode != 200) return null;
      final data = r.data;
      if (data is! Map || data['code'] != 'Ok') return null;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final first = routes.first as Map;
      final coords = (first['geometry'] as Map)['coordinates'] as List;
      final points = <LatLng>[];
      for (final c in coords) {
        // GeoJSON is [lng, lat] — flip back to LatLng(lat, lng).
        points.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
      }
      // Parse maneuvers (steps from each leg).
      final maneuvers = <Maneuver>[];
      final legs = first['legs'] as List?;
      double cumMeters = 0;
      if (legs != null) {
        for (final leg in legs) {
          final steps = (leg as Map)['steps'] as List?;
          if (steps == null) continue;
          for (final s in steps) {
            final m = (s as Map)['maneuver'] as Map?;
            if (m == null) continue;
            final loc = (m['location'] as List);
            final lng = (loc[0] as num).toDouble();
            final lat = (loc[1] as num).toDouble();
            // Index of the maneuver point within `points`. OSRM uses the same
            // geometry we got back, so we snap to the nearest coordinate.
            final idx = _nearestIndex(points, lat, lng);
            maneuvers.add(Maneuver(
              type: (m['type'] as String?) ?? '',
              modifier: (m['modifier'] as String?) ?? '',
              location: LatLng(lat, lng),
              distanceFromStart: cumMeters,
              index: idx,
            ));
            cumMeters += ((s['distance'] as num?) ?? 0).toDouble();
          }
        }
      }
      final route = RoadRoute(
        points: points,
        meters: (first['distance'] as num).toDouble(),
        seconds: (first['duration'] as num).toDouble(),
        maneuvers: maneuvers,
      );
      _routeCache[key] = _CacheEntry(route);
      return route;
    } catch (_) {
      return null;
    }
  }

  /// Pretty distance: "240 मीटर" / "1.2 कि.मी." / "12 कि.मी."
  static String formatMeters(double m) {
    if (m < 1000) return '${m.round()} मीटर';
    final km = m / 1000;
    if (km < 10) return '${km.toStringAsFixed(1)} कि.मी.';
    return '${km.round()} कि.मी.';
  }

  /// Pretty duration: "1 मिनट" / "12 मिनट" / "1 घंटा 5 मिनट".
  static String formatSeconds(double s) {
    final totalMin = (s / 60).round();
    if (totalMin < 60) return '$totalMin मिनट';
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (m == 0) return '$h घंटा';
    return '$h घंटा $m मिनट';
  }

  /// Translate an OSRM maneuver to a short Hindi voice line.
  ///
  /// Falls back to a generic instruction if we can't classify the maneuver.
  static String toHindi(Maneuver m) {
    final mod = m.modifier;
    final type = m.type;
    if (type == 'arrive') return 'गंतव्य पर पहुंचे';
    if (type == 'depart') return 'चलिए शुरू करते हैं';
    if (type == 'roundabout' || type == 'rotary') return 'राउंडअबाउट पर मुड़ें';
    if (type == 'merge') return mod == 'left' ? 'बाएँ से जुड़ें' : 'दाएँ से जुड़ें';
    if (type == 'fork') return mod == 'left' ? 'बाएँ फोर्क लें' : 'दाएँ फोर्क लें';
    if (mod == 'left' || mod == 'sharp left' || mod == 'slight left') {
      return 'बाएँ मुड़ें';
    }
    if (mod == 'right' || mod == 'sharp right' || mod == 'slight right') {
      return 'दाएँ मुड़ें';
    }
    if (mod == 'uturn') return 'यू-टर्न लें';
    if (mod == 'straight') return 'सीधे चलते रहें';
    return 'आगे बढ़ें';
  }

  /// Given the driver's current position and a route with maneuvers, return
  /// the next maneuver to announce.
  ///
  /// [driverPos] is the driver's current lat/lng.
  /// [route] is the road route (with [RoadRoute.maneuvers]).
  /// [currentIdx] is the index of the maneuver the driver has already
  /// passed (or -1 if none yet). Returns null if all maneuvers are done.
  static NextInstruction? nextInstruction({
    required LatLng driverPos,
    required RoadRoute route,
    required int currentIdx,
    double triggerMeters = 60,
  }) {
    if (route.maneuvers.isEmpty) return null;
    // Find the first maneuver the driver hasn't passed yet.
    final nextIdx = currentIdx + 1;
    if (nextIdx >= route.maneuvers.length) return null;
    final m = route.maneuvers[nextIdx];
    final distToManeuver = const Distance().as(
        LengthUnit.Meter, driverPos, m.location);
    return NextInstruction(
      maneuver: m,
      distanceMeters: distToManeuver,
      index: nextIdx,
      // Trigger when within [triggerMeters] OR when the driver has already
      // passed it (which means they missed the announcement; we re-speak).
      shouldSpeak: distToManeuver <= triggerMeters || distToManeuver < 0,
    );
  }

  /// Snap a maneuver lat/lng to the nearest point in the geometry polyline.
  static int _nearestIndex(List<LatLng> points, double lat, double lng) {
    if (points.isEmpty) return 0;
    int bestIdx = 0;
    double bestDist = double.infinity;
    const d = Distance();
    for (int i = 0; i < points.length; i++) {
      final dist = d.as(LengthUnit.Meter, points[i], LatLng(lat, lng));
      if (dist < bestDist) {
        bestDist = dist;
        bestIdx = i;
      }
    }
    return bestIdx;
  }
}

/// The next maneuver to announce (or not). [shouldSpeak] is true when the
/// driver is close enough (or already past) the maneuver.
class NextInstruction {
  final Maneuver maneuver;
  final double distanceMeters;
  final int index;
  final bool shouldSpeak;
  const NextInstruction({
    required this.maneuver,
    required this.distanceMeters,
    required this.index,
    required this.shouldSpeak,
  });

  /// "बाएँ मुड़ें" + optional preamble like "50 मीटर में".
  String hindiLine() {
    final base = Routing.toHindi(maneuver);
    if (distanceMeters < 0) return base;
    if (distanceMeters < 25) return 'अभी $base';
    if (distanceMeters < 200) return '${distanceMeters.round()} मीटर में $base';
    return base;
  }
}
