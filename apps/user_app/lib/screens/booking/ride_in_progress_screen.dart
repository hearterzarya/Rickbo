import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rickbo_core/rickbo_core.dart';
import '../../providers/ride_provider.dart';

class RideInProgressScreen extends ConsumerStatefulWidget {
  final String rideId;
  const RideInProgressScreen({super.key, required this.rideId});

  @override
  ConsumerState<RideInProgressScreen> createState() => _RideInProgressScreenState();
}

class _RideInProgressScreenState extends ConsumerState<RideInProgressScreen> {
  late final RickboSocket _socket;
  bool _sosPressed = false;

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
    });
    _socket.on('ride:completed', (data) {
      ref.read(activeRideProvider.notifier).clear();
      if (mounted) context.go('/booking/rate', extra: {'rideId': widget.rideId});
    });
  }

  @override
  void dispose() {
    _socket.off('driver:location');
    _socket.off('ride:completed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ride = ref.watch(activeRideProvider);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('सफ़र जारी है'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: line),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.electric_rickshaw, color: blue, size: 36),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${ride?.fromZone ?? '—'}  →  ${ride?.toZone ?? '—'}',
                                  style: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
                              const SizedBox(height: 2),
                              Text('किराया ₹${ride?.fare ?? 0} — ड्राइवर को नकद दें',
                                  style: GoogleFonts.hind(color: muted, fontSize: 13)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: tintGreen, borderRadius: BorderRadius.circular(12)),
                          child: Text('ONGOING',
                              style: GoogleFonts.hind(color: green, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [blue, blueDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: const Icon(Icons.person, color: blue, size: 36),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ride?.driver?['name']?.toString() ?? 'ड्राइवर',
                                  style: GoogleFonts.baloo2(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                              Text('📞 ${ride?.driver?['phone']?.toString() ?? ''}',
                                  style: GoogleFonts.hind(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.white),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // सफ़र शेयर करें — Phase 3 live link
                  _ShareRideCard(shareToken: ride?.shareToken),
                  const Spacer(),
                  Text('पहुँचने पर ड्राइवर "सफ़र पूरा" बटन दबाएगा।',
                      style: GoogleFonts.hind(color: muted, fontSize: 13)),
                ],
              ),
            ),
            Positioned(
              right: 20, bottom: 20,
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
        title: Text('मदद चाहिए?', style: GoogleFonts.baloo2(color: Colors.white, fontSize: 26)),
        content: Text('3 सेकंड में SOS भेज दिया जाएगा',
            style: GoogleFonts.hind(color: Colors.white, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _sosPressed = false);
              Navigator.pop(ctx);
            },
            child: Text('रद्द करें', style: GoogleFonts.baloo2(color: Colors.white)),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      double lat = 0, lng = 0;
      try {
        final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        ).timeout(const Duration(seconds: 4), onTimeout: () => throw Exception('gps timeout'));
        lat = p.latitude;
        lng = p.longitude;
      } catch (_) { /* still send SOS without GPS — backend logs without coords */ }
      try {
        await RickboApi().raiseSos(rideId: widget.rideId, lat: lat, lng: lng);
      } catch (e) {
        if (mounted) HindiError.show(context, e);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS भेज दिया — मदद आ रही है')),
      );
    });
  }
}

class _ShareRideCard extends StatefulWidget {
  final String? shareToken;
  const _ShareRideCard({required this.shareToken});

  @override
  State<_ShareRideCard> createState() => _ShareRideCardState();
}

class _ShareRideCardState extends State<_ShareRideCard> {
  String? _url;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    if (widget.shareToken == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final base = await ApiClient().getBaseUrl();
    if (!mounted) return;
    setState(() {
      _url = RickboApi().buildShareUrl(baseUrl: base, shareToken: widget.shareToken!);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: tintBlue, borderRadius: BorderRadius.circular(16)),
        child: const Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('लिंक तैयार हो रहा है…'),
          ],
        ),
      );
    }
    if (_url == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: tintBlue, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.share_location, color: blue),
              const SizedBox(width: 8),
              Text('सफ़र शेयर करें',
                  style: GoogleFonts.baloo2(color: blue, fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text('परिवार को भेजें — वो लाइव देख सकते हैं',
              style: GoogleFonts.hind(color: muted, fontSize: 13)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Expanded(
                  child: Text(_url!, style: GoogleFonts.hind(fontSize: 12, color: ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20, color: blue),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _url!));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('लिंक कॉपी हो गया')),
                      );
                    }
                  },
                ),
              ],
            ),
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
        child: Center(
          child: Text('SOS',
              style: GoogleFonts.baloo2(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
