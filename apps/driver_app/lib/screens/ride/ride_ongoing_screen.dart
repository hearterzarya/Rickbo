import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:rickbo_core/rickbo_core.dart';
import '../../providers/auth_provider.dart';

/// ONGOING ride screen — opens after OTP verify.
///
/// Full-screen map: driver marker (orange) → destination zone (red pin).
/// OSRM road route between them, live distance + ETA.
/// Bottom bar: "सफ़र पूरा" + "SOS".
///
/// Driver taps "सफ़र पूरा" → POST /rides/:id/complete → /ride/rate.
class RideOngoingScreen extends ConsumerStatefulWidget {
  final String rideId;
  final int fare;
  final String fromZone;
  final String toZone;
  final double pickupLat;
  final double pickupLng;
  final String userName;
  final int passengerCount;
  const RideOngoingScreen({
    super.key,
    required this.rideId,
    required this.fare,
    required this.fromZone,
    required this.toZone,
    required this.pickupLat,
    required this.pickupLng,
    required this.userName,
    required this.passengerCount,
  });

  @override
  ConsumerState<RideOngoingScreen> createState() => _RideOngoingScreenState();
}

class _RideOngoingScreenState extends ConsumerState<RideOngoingScreen> {
  bool _busy = false;
  late final RickboSocket _socket;
  Position? _driverPos;
  Timer? _locTimer;
  Timer? _routeDebounce;

  RoadRoute? _route;
  List<LatLng>? _straightFallback;
  int _announcedManeuverIdx = -1;

  // Destination zone center (looked up by zone id, e.g. 'B' → lat/lng).
  late final LatLng _dropCenter = _resolveZoneCenter(widget.toZone);

  @override
  void initState() {
    super.initState();
    _socket = ref.read(driverSocketProvider);
    _socket.on('ride:cancelled', (data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('यात्री ने रद्द कर दिया')));
      context.go('/');
    });
    _refreshLocation();
    _locTimer = Timer.periodic(const Duration(seconds: 8), (_) => _refreshLocation());
  }

  @override
  void dispose() {
    _locTimer?.cancel();
    _routeDebounce?.cancel();
    _socket.off('ride:cancelled');
    super.dispose();
  }

  Future<void> _refreshLocation() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      if (!mounted) return;
      final moved = _driverPos == null ||
          const Distance().as(LengthUnit.Meter,
              LatLng(_driverPos!.latitude, _driverPos!.longitude),
              LatLng(p.latitude, p.longitude)) >
              15;
      setState(() => _driverPos = p);
      try {
        await RickboApi().postLocation(p.latitude, p.longitude);
      } catch (_) {}
      try {
        final s = ref.read(driverSocketProvider);
        s.emit('driver:location', {'lat': p.latitude, 'lng': p.longitude});
      } catch (_) {}
      if (moved) _scheduleRouteFetch();
      _maybeAnnounceNextInstruction();
      _maybeAnnounceArrival();
    } catch (_) {}
  }

  /// When the driver is very close to the destination zone, speak
  /// "गंतव्य पर पहुंचे" once.
  bool _arrivedSpoken = false;
  void _maybeAnnounceArrival() {
    if (_arrivedSpoken) return;
    final d = _driverPos;
    if (d == null) return;
    final m = const Distance().as(
        LengthUnit.Meter, LatLng(d.latitude, d.longitude), _dropCenter);
    if (m < 40) {
      _arrivedSpoken = true;
      RickboVoice.instance.say('गंतव्य पर पहुंचे');
    }
  }

  void _scheduleRouteFetch() {
    _routeDebounce?.cancel();
    _routeDebounce = Timer(const Duration(milliseconds: 600), _fetchRoute);
  }

  Future<void> _fetchRoute() async {
    final d = _driverPos;
    if (d == null) return;
    final route = await Routing.roadRoute(
      fromLat: d.latitude,
      fromLng: d.longitude,
      toLat: _dropCenter.latitude,
      toLng: _dropCenter.longitude,
    );
    if (!mounted) return;
    final isFirstRoute = _route == null;
    setState(() {
      if (route != null) {
        _route = route;
      } else {
        _straightFallback = [
          LatLng(d.latitude, d.longitude),
          _dropCenter,
        ];
      }
    });
    if (isFirstRoute && route != null) {
      RickboVoice.instance.say('रास्ता तैयार है, चलिए');
    }
    _maybeAnnounceNextInstruction();
  }

  void _maybeAnnounceNextInstruction() {
    final r = _route;
    final d = _driverPos;
    if (r == null || d == null) return;
    final next = Routing.nextInstruction(
      driverPos: LatLng(d.latitude, d.longitude),
      route: r,
      currentIdx: _announcedManeuverIdx,
    );
    if (next == null) return;
    if (!next.shouldSpeak) return;
    if (next.distanceMeters >= 0) {
      RickboVoice.instance.say(next.hindiLine());
    }
    _announcedManeuverIdx = next.index;
  }

  Future<void> _complete() async {
    setState(() => _busy = true);
    try {
      await RickboApi().completeRide(widget.rideId);
      if (!mounted) return;
      RickboVoice.instance.say('सफ़र पूरा');
      // Show brief earnings summary, then route to the rating screen.
      // Driver STAYS online (Bug 4 fix) — the home screen reconciles from
      // server state on its next init.
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('सफ़र पूरा! 🎉',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          content: Text('₹${widget.fare} कमाए — नकद मिल गए',
              style: TextStyle(color: Colors.white, fontSize: 18)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) {
                  context.go('/ride/rate', extra: {'rideId': widget.rideId});
                }
              },
              child: Text('ठीक है',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) HindiError.show(context, e);
      setState(() => _busy = false);
    }
  }

  (String, String) _etaTexts() {
    final r = _route;
    if (r != null) {
      return (
        Routing.formatMeters(r.meters),
        Routing.formatSeconds(r.seconds),
      );
    }
    final d = _driverPos;
    if (d == null) return ('—', '—');
    final meters = const Distance().as(
        LengthUnit.Meter, LatLng(d.latitude, d.longitude), _dropCenter);
    final secs = meters / 8.33;
    return (
      Routing.formatMeters(meters),
      Routing.formatSeconds(secs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = <MapMarker>[
      MapMarker(
        lat: _dropCenter.latitude,
        lng: _dropCenter.longitude,
        icon: Icons.location_on,
        color: red,
        label: widget.toZone,
        size: 60,
      ),
    ];
    final routes = <MapRoute>[];
    final pts = _route?.points ?? _straightFallback;
    if (pts != null && pts.length >= 2) {
      routes.add(MapRoute(points: pts, color: blue, width: 5));
    }
    if (_driverPos != null) {
      markers.insert(
        0,
        MapMarker(
          lat: _driverPos!.latitude,
          lng: _driverPos!.longitude,
          icon: Icons.electric_rickshaw,
          color: const Color(0xFFFF6B00),
          label: 'मैं',
          size: 56,
        ),
      );
    }
    final centerLat = _driverPos?.latitude ?? _dropCenter.latitude;
    final centerLng = _driverPos?.longitude ?? _dropCenter.longitude;
    final (distText, etaText) = _etaTexts();
    final hasGps = _driverPos != null;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: RickboMap(
                centerLat: centerLat,
                centerLng: centerLng,
                zoom: 14.5,
                markers: markers,
                routes: routes,
                showZoneDots: false,
                interactive: true,
              ),
            ),

            // Top: live ETA + destination info.
            Positioned(
              top: 12, left: 12, right: 12,
              child: _OngoingHeader(
                fromZone: widget.fromZone,
                toZone: widget.toZone,
                userName: widget.userName,
                pax: widget.passengerCount,
                fare: widget.fare,
                distText: distText,
                etaText: etaText,
                hasGps: hasGps,
              ),
            ),

            // Bottom: complete + SOS.
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, -2)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _complete,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(60),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                            ),
                            child: Text('सफ़र पूरा  ✓  ₹${widget.fare}',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // SOS floating button (always visible mid-ride).
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 130,
              child: _DriverSosButton(onPressed: () => _sosFlow()),
            ),
          ],
        ),
      ),
    );
  }

  void _sosFlow() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: red,
        title: Text('मदद चाहिए?', style: TextStyle(color: Colors.white, fontSize: 26)),
        content: Text('3 सेकंड में SOS भेज दिया जाएगा',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('रद्द करें', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      double lat = _driverPos?.latitude ?? 0;
      double lng = _driverPos?.longitude ?? 0;
      // Only claim "मदद आ रही है" if POST succeeded.
      try {
        await RickboApi().raiseSos(rideId: widget.rideId, lat: lat, lng: lng);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS भेज दिया — मदद आ रही है')),
        );
      } catch (e) {
        if (!mounted) return;
        HindiError.show(context, e);
      }
    });
  }

  /// Maps zone id ('A'/'B'/...) → zone center LatLng via the shared zones table.
  LatLng _resolveZoneCenter(String zoneNameOrId) {
    // toZone might be the human name; try to match by id first, then by name.
    final matches = zones.where((z) =>
        (z['id'] as String) == zoneNameOrId ||
        (z['name'] as String) == zoneNameOrId);
    if (matches.isNotEmpty) {
      final z = matches.first;
      return LatLng(z['lat'] as double, z['lng'] as double);
    }
    // Fallback to Najibabad town center.
    return const LatLng(29.6094, 78.3438);
  }
}

class _OngoingHeader extends StatelessWidget {
  final String fromZone;
  final String toZone;
  final String userName;
  final int pax;
  final int fare;
  final String distText;
  final String etaText;
  final bool hasGps;
  const _OngoingHeader({
    required this.fromZone,
    required this.toZone,
    required this.userName,
    required this.pax,
    required this.fare,
    required this.distText,
    required this.etaText,
    required this.hasGps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: tintGreen, shape: BoxShape.circle),
                child: const Icon(Icons.electric_rickshaw, color: green, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('सफ़र जारी है',
                        style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
                    Text('$fromZone  →  $toZone',
                        style: TextStyle(fontSize: 15, color: ink, fontWeight: FontWeight.w800),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(20)),
                child: Text('₹$fare',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: line),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  icon: Icons.straighten,
                  label: 'गंतव्य तक',
                  value: hasGps ? distText : 'GPS खोज रहे…',
                  iconColor: red,
                ),
              ),
              Container(width: 1, height: 36, color: line),
              Expanded(
                child: _Metric(
                  icon: Icons.access_time,
                  label: 'ETA',
                  value: hasGps ? etaText : '—',
                  iconColor: red,
                ),
              ),
              Container(width: 1, height: 36, color: line),
              Expanded(
                child: _Metric(
                  icon: Icons.person,
                  label: 'यात्री',
                  value: '$pax · $userName',
                  iconColor: blue,
                  tight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final bool tight;
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.tight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: muted),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: muted)),
          ]),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: tight ? 13 : 15, color: ink, fontWeight: FontWeight.w800),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DriverSosButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _DriverSosButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: red,
          boxShadow: [BoxShadow(color: red.withOpacity(0.4), blurRadius: 18, spreadRadius: 4)],
        ),
        child: const Center(
          child: Text('SOS',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
