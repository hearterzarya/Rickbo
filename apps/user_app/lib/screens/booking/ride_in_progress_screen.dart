import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:rickbo_core/rickbo_core.dart';
import '../../providers/ride_provider.dart';

/// ONGOING screen for the user.
///
/// Full-screen map showing the rickshaw moving toward the destination zone.
/// Driver location updates via `driver:location` socket event, OSRM polyline
/// is re-fetched on each significant move.
///
/// Bottom bar: route summary (from → to), fare chip, share link, cancel.
/// SOS floating action button.
class RideInProgressScreen extends ConsumerStatefulWidget {
  final String rideId;
  const RideInProgressScreen({super.key, required this.rideId});

  @override
  ConsumerState<RideInProgressScreen> createState() => _RideInProgressScreenState();
}

class _RideInProgressScreenState extends ConsumerState<RideInProgressScreen> {
  late final RickboSocket _socket;
  bool _sosPressed = false;

  // Last fetched route to drop zone. Stays visible while we re-fetch.
  RoadRoute? _route;
  List<LatLng>? _straightFallback;
  Timer? _routeDebounce;
  String? _lastRouteKey;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketProvider);
    _socket.on('driver:location', (data) {
      if (data is! Map) return;
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      ref.read(activeRideProvider.notifier).update((r) => r.copyWith(driverLat: lat, driverLng: lng));
      _scheduleRouteFetch();
    });
    _socket.on('ride:completed', (data) {
      final driverId = ref.read(activeRideProvider)?.driver?['id']?.toString() ?? '';
      ref.read(activeRideProvider.notifier).clear();
      if (mounted) {
        context.go('/booking/rate', extra: {'rideId': widget.rideId, 'driverId': driverId});
      }
    });
    // First route fetch on screen open.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleRouteFetch());
  }

  @override
  void dispose() {
    _routeDebounce?.cancel();
    _socket.off('driver:location');
    _socket.off('ride:completed');
    super.dispose();
  }

  void _scheduleRouteFetch() {
    _routeDebounce?.cancel();
    _routeDebounce = Timer(const Duration(milliseconds: 700), _fetchRoute);
  }

  Future<void> _fetchRoute() async {
    final ride = ref.read(activeRideProvider);
    if (ride?.driverLat == null || ride?.driverLng == null) return;
    final drop = _dropCenterFor(ride?.toZone);
    // Cheap de-dup: skip if last route was for essentially the same driver pos.
    final key = '${ride!.driverLat!.toStringAsFixed(4)},${ride.driverLng!.toStringAsFixed(4)}->${drop.latitude.toStringAsFixed(4)},${drop.longitude.toStringAsFixed(4)}';
    if (key == _lastRouteKey && _route != null) return;
    _lastRouteKey = key;

    final route = await Routing.roadRoute(
      fromLat: ride.driverLat!,
      fromLng: ride.driverLng!,
      toLat: drop.latitude,
      toLng: drop.longitude,
    );
    if (!mounted) return;
    setState(() {
      if (route != null) {
        _route = route;
      } else if (ride.driverLat != null && ride.driverLng != null) {
        _straightFallback = [
          LatLng(ride.driverLat!, ride.driverLng!),
          drop,
        ];
      }
    });
  }

  /// Drop zone center for the user's destination zone id.
  LatLng _dropCenterFor(String? zoneIdOrName) {
    if (zoneIdOrName == null || zoneIdOrName.isEmpty) {
      return const LatLng(29.6094, 78.3438);
    }
    final matches = zones.where((z) =>
        (z['id'] as String) == zoneIdOrName ||
        (z['name'] as String) == zoneIdOrName);
    if (matches.isNotEmpty) {
      final z = matches.first;
      return LatLng(z['lat'] as double, z['lng'] as double);
    }
    return const LatLng(29.6094, 78.3438);
  }

  (String, String) _etaTexts(ActiveRide? ride) {
    final r = _route;
    if (r != null) {
      return (
        Routing.formatMeters(r.meters),
        Routing.formatSeconds(r.seconds),
      );
    }
    if (ride?.driverLat == null) return ('—', '—');
    final drop = _dropCenterFor(ride?.toZone);
    final meters = const Distance().as(
        LengthUnit.Meter, LatLng(ride!.driverLat!, ride.driverLng!), drop);
    return (
      Routing.formatMeters(meters),
      Routing.formatSeconds(meters / 8.33),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ride = ref.watch(activeRideProvider);
    final driverLat = ride?.driverLat;
    final driverLng = ride?.driverLng;
    final drop = _dropCenterFor(ride?.toZone);

    final markers = <MapMarker>[
      MapMarker(
        lat: drop.latitude,
        lng: drop.longitude,
        icon: Icons.location_on,
        color: red,
        label: ride?.toZone ?? 'गंतव्य',
        size: 60,
      ),
    ];
    final routes = <MapRoute>[];
    final pts = _route?.points ?? _straightFallback;
    if (pts != null && pts.length >= 2) {
      routes.add(MapRoute(points: pts, color: blue, width: 5));
    }
    if (driverLat != null && driverLng != null) {
      markers.insert(
        0,
        MapMarker(
          lat: driverLat,
          lng: driverLng,
          icon: Icons.electric_rickshaw,
          color: const Color(0xFFFF6B00),
          label: 'रिक्शा',
          size: 56,
        ),
      );
    }
    final centerLat = driverLat ?? drop.latitude;
    final centerLng = driverLng ?? drop.longitude;
    final (distText, etaText) = _etaTexts(ride);
    final hasDriverGps = driverLat != null;

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
                zoom: 14.5,
                markers: markers,
                routes: routes,
                showZoneDots: false,
                interactive: true,
              ),
            ),

            // Top: live ETA card.
            Positioned(
              top: 12, left: 12, right: 12,
              child: _InProgressHeader(
                fromZone: ride?.fromZone ?? '—',
                toZone: ride?.toZone ?? '—',
                fare: ride?.fare ?? 0,
                distText: distText,
                etaText: etaText,
                hasDriverGps: hasDriverGps,
                driverName: ride?.driver?['name']?.toString() ?? 'ड्राइवर',
                driverPhone: ride?.driver?['phone']?.toString() ?? '',
                shareToken: ride?.shareToken,
              ),
            ),

            // Bottom: share link + cancel.
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
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _cancelRideFlow(),
                          icon: const Icon(Icons.cancel_outlined, color: red),
                          label: const Text('सफ़र रद्द करें', style: TextStyle(color: red)),
                        ),
                      ),
                      Text('पहुँचने पर ड्राइवर "सफ़र पूरा" बटन दबाएगा।',
                          style: TextStyle(color: muted, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),

            // SOS button.
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 120,
              child: _SosButton(
                pressed: _sosPressed,
                onPressed: () => _sosFlow(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sosFlow() {
    setState(() => _sosPressed = true);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: red,
        title: Text('मदद चाहिए?', style: TextStyle(color: Colors.white, fontSize: 26)),
        content: Text('3 सेकंड में SOS भेज दिया जाएगा',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _sosPressed = false);
              Navigator.pop(ctx);
            },
            child: Text('रद्द करें', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      // Reuse the pickup location captured at booking time. The user app has
      // no in-flight location stream, and a fresh GPS read here would add
      // 4s on top of the 3s cancel window — bad UX in a real emergency.
      // If pickup is also null (e.g. permission denied), send 0,0 and let
      // the backend log the SOS anyway.
      final ride = ref.read(activeRideProvider);
      final lat = ride?.pickupLat ?? 0;
      final lng = ride?.pickupLng ?? 0;
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

  void _cancelRideFlow() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        title: const Text('सफ़र रद्द करें?', style: TextStyle(color: ink, fontSize: 22)),
        content: const Text('क्या आप वाकई यह सफ़र रद्द करना चाहते हैं?',
            style: TextStyle(color: ink, fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('नहीं', style: TextStyle(color: blue)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await RickboApi().cancelRide(widget.rideId);
                ref.read(activeRideProvider.notifier).clear();
                if (mounted) context.go('/');
              } catch (e) {
                if (mounted) HindiError.show(context, e);
              }
            },
            child: const Text('हाँ, रद्द करें', style: TextStyle(color: red)),
          ),
        ],
      ),
    );
  }
}

class _InProgressHeader extends StatelessWidget {
  final String fromZone;
  final String toZone;
  final int fare;
  final String distText;
  final String etaText;
  final bool hasDriverGps;
  final String driverName;
  final String driverPhone;
  final String? shareToken;
  const _InProgressHeader({
    required this.fromZone,
    required this.toZone,
    required this.fare,
    required this.distText,
    required this.etaText,
    required this.hasDriverGps,
    required this.driverName,
    required this.driverPhone,
    required this.shareToken,
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
                  value: hasDriverGps ? distText : 'रिक्शा मिल रही है…',
                  iconColor: red,
                ),
              ),
              Container(width: 1, height: 36, color: line),
              Expanded(
                child: _Metric(
                  icon: Icons.access_time,
                  label: 'ETA',
                  value: hasDriverGps ? etaText : '—',
                  iconColor: red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: line),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: tintBlue, shape: BoxShape.circle),
                child: const Icon(Icons.person, color: blue, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driverName,
                        style: TextStyle(fontSize: 14, color: ink, fontWeight: FontWeight.w800),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (driverPhone.isNotEmpty)
                      Text('📞 $driverPhone',
                          style: TextStyle(fontSize: 12, color: muted),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _ShareButton(shareToken: shareToken),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatefulWidget {
  final String? shareToken;
  const _ShareButton({required this.shareToken});
  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  String? _url;
  bool _built = false;

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    if (widget.shareToken == null) {
      setState(() => _built = true);
      return;
    }
    final base = await ApiClient().getBaseUrl();
    if (!mounted) return;
    setState(() {
      _url = RickboApi().buildShareUrl(baseUrl: base, shareToken: widget.shareToken!);
      _built = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_built) return const SizedBox(width: 32, height: 32);
    if (_url == null) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.share_location, color: blue),
      tooltip: 'सफ़र शेयर करें',
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: _url!));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('लिंक कॉपी हो गया')),
          );
        }
      },
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
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
            style: TextStyle(fontSize: 14, color: ink, fontWeight: FontWeight.w800),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  final bool pressed;
  final VoidCallback onPressed;
  const _SosButton({required this.pressed, required this.onPressed});

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
