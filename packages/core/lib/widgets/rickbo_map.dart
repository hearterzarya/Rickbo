import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../zones.dart';
import '../theme.dart';

/// One map marker definition. [icon] is shown at the location; [color] is the
/// pin background; [label] is an optional label that renders below the pin.
class MapMarker {
  final double lat;
  final double lng;
  final IconData icon;
  final Color color;
  final String? label;
  final double? size; // override default pin size

  const MapMarker({
    required this.lat,
    required this.lng,
    this.icon = Icons.location_on,
    this.color = blue,
    this.label,
    this.size,
  });
}

/// A polyline on the map (e.g. driver → pickup).
class MapRoute {
  final List<LatLng> points;
  final Color color;
  final double width;
  const MapRoute({
    required this.points,
    this.color = blue,
    this.width = 4,
  });
}

/// Reusable OpenStreetMap widget for Rickbo.
///
/// - Default Najibabad center, zoom 14
/// - Optional translucent zone circles for context
/// - Renders markers as colored pins with icons
/// - Renders polylines for routes
/// - `interactive: false` makes it a static preview (good for home cards)
class RickboMap extends StatelessWidget {
  final double centerLat;
  final double centerLng;
  final double zoom;
  final List<MapMarker> markers;
  final List<MapRoute> routes;
  final bool showZoneDots;
  final bool fitToMarkers;
  final bool interactive;

  const RickboMap({
    super.key,
    this.centerLat = 29.6094,
    this.centerLng = 78.3438,
    this.zoom = 14,
    this.markers = const [],
    this.routes = const [],
    this.showZoneDots = true,
    this.fitToMarkers = false,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(centerLat, centerLng),
        initialZoom: zoom,
        minZoom: 11,
        maxZoom: 18,
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all
              : InteractiveFlag.none,
        ),
      ),
      children: [
        // OpenStreetMap tile layer (free, no API key).
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.rickbo.driver_app',
          maxZoom: 19,
        ),
        // Translucent zone circles (pickup area context).
        if (showZoneDots)
          CircleLayer(
            circles: [
              for (final z in zones)
                CircleMarker(
                  point: LatLng(z['lat'] as double, z['lng'] as double),
                  radius: (z['radius'] as num).toDouble(),
                  useRadiusInMeter: true,
                  color: blue.withOpacity(0.08),
                  borderColor: blue.withOpacity(0.35),
                  borderStrokeWidth: 1.5,
                ),
            ],
          ),
        // Polylines (e.g. driver → pickup).
        if (routes.isNotEmpty)
          PolylineLayer(
            polylines: [
              for (final r in routes)
                Polyline(
                  points: r.points,
                  color: r.color,
                  strokeWidth: r.width,
                  borderColor: r.color.withOpacity(0.4),
                  borderStrokeWidth: 1.5,
                ),
            ],
          ),
        // Markers.
        if (markers.isNotEmpty)
          MarkerLayer(
            markers: [
              for (final m in markers)
                Marker(
                  point: LatLng(m.lat, m.lng),
                  width: m.size ?? 56,
                  height: m.size ?? 64,
                  alignment: Alignment.topCenter,
                  child: _Pin(m: m),
                ),
            ],
          ),
        // Attribution (required by OSM license).
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  final MapMarker m;
  const _Pin({required this.m});

  @override
  Widget build(BuildContext context) {
    final size = m.size ?? 56.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: m.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: m.color.withOpacity(0.5),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Icon(m.icon, color: Colors.white, size: size * 0.5),
        ),
        // Pointer tail.
        Container(
          width: 2,
          height: 8,
          color: m.color,
        ),
        if (m.label != null && m.label!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              m.label!,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}
