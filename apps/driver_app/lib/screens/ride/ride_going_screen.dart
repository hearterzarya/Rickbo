import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:rickbo_core/rickbo_core.dart';
import '../../providers/auth_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _socket = ref.read(driverSocketProvider);
    _socket.on('ride:cancelled', (data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('यात्री ने रद्द कर दिया')));
      context.go('/');
    });
    // Update driver location while en route so the map stays live.
    _refreshLocation();
    _locTimer = Timer.periodic(const Duration(seconds: 8), (_) => _refreshLocation());
  }

  @override
  void dispose() {
    _locTimer?.cancel();
    _socket.off('ride:cancelled');
    super.dispose();
  }

  Future<void> _refreshLocation() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      if (mounted) setState(() => _driverPos = p);
    } catch (_) {}
  }

  Future<void> _arrived() async {
    setState(() => _busy = true);
    try {
      await RickboApi().markArrived(widget.rideId);
      if (!mounted) return;
      // Phase 5: voice prompt when driver arrives at pickup.
      RickboVoice.instance.say('पहुंच गए');
      context.go('/ride/otp', extra: {
        'rideId': widget.rideId,
        'fare': widget.fare,
        'toZone': widget.toZone,
        'userName': widget.userName,
      });
    } catch (_) {
      setState(() => _busy = false);
    }
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
      ),
    ];
    final routes = <MapRoute>[];
    if (_driverPos != null) {
      markers.insert(
        0,
        MapMarker(
          lat: _driverPos!.latitude,
          lng: _driverPos!.longitude,
          icon: Icons.electric_rickshaw,
          color: const Color(0xFFFF6B00),
          label: 'मैं',
        ),
      );
      routes.add(MapRoute(
        points: [
          LatLng(_driverPos!.latitude, _driverPos!.longitude),
          LatLng(widget.pickupLat, widget.pickupLng),
        ],
        color: blue,
        width: 4,
      ));
    }
    final centerLat = _driverPos?.latitude ?? widget.pickupLat;
    final centerLng = _driverPos?.longitude ?? widget.pickupLng;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('पिकअप पर जाएँ')),
      body: Column(
        children: [
          // Live navigation map: driver (orange) → pickup (blue).
          SizedBox(
            height: 280,
            child: Stack(
              children: [
                Positioned.fill(
                  child: RickboMap(
                    centerLat: centerLat,
                    centerLng: centerLng,
                    zoom: 15,
                    markers: markers,
                    routes: routes,
                    showZoneDots: true,
                    interactive: true,
                  ),
                ),
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.navigation, color: blue, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          widget.fromZone,
                          style: GoogleFonts.hind(fontSize: 13, fontWeight: FontWeight.w700, color: ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [cyan, blue], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [blueShadow()],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.navigation, color: Colors.white, size: 48),
                        const SizedBox(height: 8),
                        Text('पिकअप पर जा रहे हैं',
                            style: GoogleFonts.baloo2(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(widget.fromZone,
                            style: GoogleFonts.hind(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
                    child: Row(
                      children: [
                        Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(color: tintBlue, shape: BoxShape.circle),
                          child: const Icon(Icons.person, color: blue, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.userName, style: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
                              const SizedBox(height: 2),
                              Text('${widget.passengerCount} यात्री', style: GoogleFonts.hind(color: muted, fontSize: 13)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(20)),
                          child: Text('₹${widget.fare}',
                              style: GoogleFonts.baloo2(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: red, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('उतरना', style: GoogleFonts.hind(color: muted, fontSize: 12)),
                              Text(widget.toZone, style: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _busy
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
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
                                style: GoogleFonts.baloo2(fontSize: 20, fontWeight: FontWeight.w800)),
                          ),
                        ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () async {
                        try { await RickboApi().cancelRide(widget.rideId); } catch (_) {}
                        if (mounted) context.go('/');
                      },
                      child: Text('रद्द करें', style: GoogleFonts.hind(color: muted)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
