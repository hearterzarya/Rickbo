import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rickbo_core/rickbo_core.dart';
import '../../providers/auth_provider.dart';

class IncomingOfferScreen extends ConsumerStatefulWidget {
  final String rideId;
  final String fromZone;
  final String toZone;
  final int fare;
  final double pickupLat;
  final double pickupLng;
  final int passengerCount;
  final String userName;
  const IncomingOfferScreen({
    super.key,
    required this.rideId,
    required this.fromZone,
    required this.toZone,
    required this.fare,
    required this.pickupLat,
    required this.pickupLng,
    required this.passengerCount,
    required this.userName,
  });

  @override
  ConsumerState<IncomingOfferScreen> createState() => _IncomingOfferScreenState();
}

class _IncomingOfferScreenState extends ConsumerState<IncomingOfferScreen> {
  int _secs = 20;
  Timer? _t;
  bool _deciding = false;
  late final RickboSocket _socket;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(driverSocketProvider);
    _socket.on('ride:cancelled', (data) {
      if (mounted) _goHome('यात्री ने रद्द कर दिया');
    });
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secs--);
      if (_secs <= 0) {
        _t?.cancel();
        _autoSkip();
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _socket.off('ride:cancelled');
    super.dispose();
  }

  Future<void> _autoSkip() async {
    if (_deciding) return;
    _deciding = true;
    try {
      await RickboApi().declineRide(widget.rideId, reason: 'timeout');
    } catch (_) {}
    if (!mounted) return;
    _goHome('कोई रिक्शा नहीं मिली — रद्द करें');
  }

  Future<void> _accept() async {
    if (_deciding) return;
    _deciding = true;
    _t?.cancel();
    try {
      await RickboApi().acceptRide(widget.rideId);
      if (!mounted) return;
      context.go('/ride/going', extra: {
        'rideId': widget.rideId,
        'fare': widget.fare,
        'fromZone': widget.fromZone,
        'toZone': widget.toZone,
        'pickupLat': widget.pickupLat,
        'pickupLng': widget.pickupLng,
        'userName': widget.userName,
        'passengerCount': widget.passengerCount,
      });
    } catch (e) {
      if (!mounted) return;
      _goHome('ऑफर एक्सपायर हो गया');
    }
  }

  Future<void> _decline() async {
    if (_deciding) return;
    _deciding = true;
    _t?.cancel();
    try {
      await RickboApi().declineRide(widget.rideId, reason: 'driver-declined');
    } catch (_) {}
    if (!mounted) return;
    _goHome();
  }

  void _goHome([String? toast]) {
    if (toast != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secs / 20.0;
    return Scaffold(
      backgroundColor: blue,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
                    child: Text('नई सवारी',
                        style: GoogleFonts.baloo2(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      const Icon(Icons.timer, color: blue, size: 18),
                      const SizedBox(width: 4),
                      Text('$_secs sec',
                          style: GoogleFonts.baloo2(color: blue, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: progress, minHeight: 6, color: gold, backgroundColor: Colors.white24),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(26)),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [green, Color(0xFF1F7A2E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        boxShadow: [BoxShadow(color: green.withOpacity(0.4), blurRadius: 20, spreadRadius: 4)],
                      ),
                      child: Center(
                        child: Text('₹${widget.fare}',
                            style: GoogleFonts.baloo2(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('पक्का किराया', style: GoogleFonts.hind(color: muted, fontSize: 13)),
                    const SizedBox(height: 22),
                    _RouteRow(from: widget.fromZone, to: widget.toZone),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        _StatPill(icon: Icons.person, label: 'यात्री', value: '${widget.passengerCount}'),
                        const SizedBox(width: 10),
                        _StatPill(icon: Icons.account_circle, label: 'ग्राहक', value: widget.userName),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: tintCyan, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: cyan, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('पिकअप', style: GoogleFonts.hind(color: muted, fontSize: 12)),
                                Text('${widget.pickupLat.toStringAsFixed(4)}, ${widget.pickupLng.toStringAsFixed(4)}',
                                    style: GoogleFonts.baloo2(color: blue, fontSize: 14, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _decline,
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.close, color: Colors.white, size: 28),
                              const SizedBox(width: 8),
                              Text('ना', style: GoogleFonts.baloo2(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _accept,
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(
                          color: green,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: green.withOpacity(0.5), blurRadius: 18)],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check, color: Colors.white, size: 32),
                              const SizedBox(width: 8),
                              Text('हाँ, सवारी लो', style: GoogleFonts.baloo2(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final String from;
  final String to;
  const _RouteRow({required this.from, required this.to});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
      child: Column(
        children: [
          Row(children: [
            const Icon(Icons.circle, color: green, size: 14),
            const SizedBox(width: 10),
            Expanded(child: Text(from, style: GoogleFonts.hind(color: ink, fontSize: 16, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(width: 2, height: 18, color: line),
          ),
          Row(children: [
            const Icon(Icons.location_on, color: red, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(to, style: GoogleFonts.hind(color: ink, fontSize: 16, fontWeight: FontWeight.w700))),
          ]),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatPill({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: muted),
              const SizedBox(width: 4),
              Text(label, style: GoogleFonts.hind(color: muted, fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w800, color: ink), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}