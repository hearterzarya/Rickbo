import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:rickbo_core/rickbo_core.dart';
import '../../providers/auth_provider.dart';

/// Full-screen driver→pickup navigation.
///
/// Layout:
/// - Full-screen [RickboMap] showing driver marker (orange rickshaw), user
///   pickup pin (blue), and the road polyline fetched from OSRM.
/// - Top status card: live distance + ETA ("उपयोगकर्ता तक: 600 मीटर · 3 मिनट")
///   plus passenger info.
/// - Bottom action bar: "मैं पहुँच गया" button + SOS + cancel.
///
/// The OSRM route is re-fetched (debounced) whenever the driver moves more
/// than ~15 m. While the route is being re-fetched we keep showing the last
/// known polyline + ETA so the screen never flashes.
class RideGoingScreen extends ConsumerStatefulWidget {
  final String rideId;
  final int fare;
  final String fromZone;
  final String toZone;
  final double pickupLat;
  final double pickupLng;
  final String userName;
  final int passengerCount;
  const RideGoingScreen({
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
  ConsumerState<RideGoingScreen> createState() => _RideGoingScreenState();
}

class _RideGoingScreenState extends ConsumerState<RideGoingScreen> {
  bool _busy = false;
  late final RickboSocket _socket;
  Position? _driverPos;
  Timer? _locTimer;
  Timer? _routeDebounce;

  /// Last road route we successfully fetched. Stays visible while we re-fetch
  /// so the polyline never disappears during the brief OSRM hop.
  RoadRoute? _route;

  /// Fallback straight-line polyline when OSRM hasn't returned yet.
  List<LatLng>? _straightFallback;

  /// Index of the last maneuver we already announced. -1 = nothing yet.
  int _announcedManeuverIdx = -1;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(driverSocketProvider);
    _socket.on('ride:cancelled', (data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('यात्री ने रद्द कर दिया')));
      context.go('/');
    });
    // First location fix → first route fetch.
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
      // Push to backend + socket (best-effort, never blocks UI).
      try {
        await RickboApi().postLocation(p.latitude, p.longitude);
      } catch (_) {}
      try {
        final s = ref.read(driverSocketProvider);
        s.emit('driver:location', {'lat': p.latitude, 'lng': p.longitude});
      } catch (_) {}
      // Re-route only when the driver moved enough.
      if (moved) _scheduleRouteFetch();
      // Always check for the next voice instruction — driver may have moved
      // closer to the next maneuver even without triggering a re-route.
      _maybeAnnounceNextInstruction();
      _maybeAnnounceArrival();
    } catch (_) {}
  }

  /// When the driver is very close to the pickup, speak "पहुंच गए" once.
  /// (The "मैं पहुँच गया" button still triggers the same voice explicitly.)
  bool _arrivedSpoken = false;
  void _maybeAnnounceArrival() {
    if (_arrivedSpoken) return;
    final d = _driverPos;
    if (d == null) return;
    final m = const Distance().as(
        LengthUnit.Meter,
        LatLng(d.latitude, d.longitude),
        LatLng(widget.pickupLat, widget.pickupLng));
    if (m < 40) {
      _arrivedSpoken = true;
      RickboVoice.instance.say('पहुंच गए');
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
      toLat: widget.pickupLat,
      toLng: widget.pickupLng,
    );
    if (!mounted) return;
    final isFirstRoute = _route == null;
    setState(() {
      if (route != null) {
        _route = route;
      } else {
        // Fallback: straight line so the map still shows a path.
        _straightFallback = [
          LatLng(d.latitude, d.longitude),
          LatLng(widget.pickupLat, widget.pickupLng),
        ];
      }
    });
    if (isFirstRoute && route != null) {
      RickboVoice.instance.say('रास्ता तैयार है, चलिए');
    }
    _maybeAnnounceNextInstruction();
  }

  /// Called after every location/route update. Speaks the next maneuver in
  /// Hindi if the driver is within ~60 m of it AND we haven't already spoken
  /// it. Re-speaks (one time) if the driver has already passed it.
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
    // Speak and advance the pointer.
    final line = next.hindiLine();
    if (next.maneuver.type == 'arrive') {
      RickboVoice.instance.say(line);
    } else if (next.distanceMeters < 0) {
      // Driver overshot — just announce the following maneuver silently.
      // Don't spam.
    } else {
      RickboVoice.instance.say(line);
    }
    _announcedManeuverIdx = next.index;
  }

  Future<void> _arrived() async {
    setState(() => _busy = true);
    try {
      await RickboApi().markArrived(widget.rideId);
      if (!mounted) return;
      RickboVoice.instance.say('पहुंच गए');
      context.go('/ride/otp', extra: {
        'rideId': widget.rideId,
        'fare': widget.fare,
        'fromZone': widget.fromZone,
        'toZone': widget.toZone,
        'pickupLat': widget.pickupLat,
        'pickupLng': widget.pickupLng,
        'userName': widget.userName,
        'passengerCount': widget.passengerCount,
      });
    } catch (_) {
      setState(() => _busy = false);
    }
  }

  /// Distance + ETA to show in the top status card. Prefers OSRM numbers;
  /// falls back to haversine + 30 km/h estimate if OSRM hasn't returned yet.
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
    final meters = const Distance().as(LengthUnit.Meter,
        LatLng(d.latitude, d.longitude),
        LatLng(widget.pickupLat, widget.pickupLng));
    // 30 km/h → 8.33 m/s. Rough estimate when OSRM hasn't loaded yet.
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
        lat: widget.pickupLat,
        lng: widget.pickupLng,
        icon: Icons.person_pin_circle,
        color: blue,
        label: widget.userName,
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
    final centerLat = _driverPos?.latitude ?? widget.pickupLat;
    final centerLng = _driverPos?.longitude ?? widget.pickupLng;
    final (distText, etaText) = _etaTexts();
    final hasGps = _driverPos != null;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Full-screen map.
            Positioned.fill(
              child: RickboMap(
                centerLat: centerLat,
                centerLng: centerLng,
                zoom: 15.5,
                markers: markers,
                routes: routes,
                showZoneDots: false,
                interactive: true,
              ),
            ),

            // Top: live ETA card.
            Positioned(
              top: 12, left: 12, right: 12,
              child: _EtaCard(
                fromZone: widget.fromZone,
                distText: distText,
                etaText: etaText,
                hasGps: hasGps,
                userName: widget.userName,
                pax: widget.passengerCount,
                fare: widget.fare,
              ),
            ),

            // Bottom: arrived button + cancel.
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
                            onPressed: _arrived,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(60),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                            ),
                            child: Text('मैं पहुँच गया',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () async {
                          try { await RickboApi().cancelRide(widget.rideId); } catch (_) {}
                          if (mounted) context.go('/');
                        },
                        child: Text('रद्द करें', style: TextStyle(color: muted)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // SOS always visible during a ride.
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 130,
              child: _DriverSosButton(
                onPressed: () => _sosFlow(),
              ),
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
      // Only show success if POST succeeded. On failure, HindiError already
      // shows a clean Hindi message — never claim "मदद आ रही है" if nothing
      // was actually sent.
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
}

/// Top status card: "उपयोगकर्ता तक: 600 मीटर · 3 मिनट" + passenger + fare.
class _EtaCard extends StatelessWidget {
  final String fromZone;
  final String distText;
  final String etaText;
  final bool hasGps;
  final String userName;
  final int pax;
  final int fare;
  const _EtaCard({
    required this.fromZone,
    required this.distText,
    required this.etaText,
    required this.hasGps,
    required this.userName,
    required this.pax,
    required this.fare,
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
                decoration: BoxDecoration(color: tintBlue, shape: BoxShape.circle),
                child: const Icon(Icons.navigation, color: blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('पिकअप पर जा रहे हैं',
                        style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
                    Text(fromZone,
                        style: TextStyle(fontSize: 16, color: ink, fontWeight: FontWeight.w800),
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
                  label: 'उपयोगकर्ता तक',
                  value: hasGps ? distText : 'GPS खोज रहे…',
                  iconColor: blue,
                ),
              ),
              Container(width: 1, height: 36, color: line),
              Expanded(
                child: _Metric(
                  icon: Icons.access_time,
                  label: 'ETA',
                  value: hasGps ? etaText : '—',
                  iconColor: blue,
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
