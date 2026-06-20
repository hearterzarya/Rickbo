import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rickbo_core/rickbo_core.dart';
import '../../providers/ride_provider.dart';

class DriverAssignedScreen extends ConsumerStatefulWidget {
  final String rideId;
  const DriverAssignedScreen({super.key, required this.rideId});

  @override
  ConsumerState<DriverAssignedScreen> createState() => _DriverAssignedScreenState();
}

class _DriverAssignedScreenState extends ConsumerState<DriverAssignedScreen> {
  late final RickboSocket _socket;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketProvider);
    _socket.on('driver:location', (data) {
      if (data is! Map) return;
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      ref.read(activeRideProvider.notifier).update((r) => r.copyWith(
            driverLat: lat, driverLng: lng,
          ));
    });
    _socket.on('ride:arrived', (data) {
      ref.read(activeRideProvider.notifier).update((r) => r.copyWith(status: 'ARRIVED'));
      if (mounted) _showArrivedDialog();
    });
    _socket.on('ride:started', (data) {
      ref.read(activeRideProvider.notifier).update((r) => r.copyWith(status: 'ONGOING'));
      if (mounted) context.go('/booking/ride', extra: {'rideId': widget.rideId});
    });
    _socket.on('ride:cancelled', (data) {
      ref.read(activeRideProvider.notifier).clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('रिक्शा वाला रद्द कर गया')));
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    _socket.off('driver:location');
    _socket.off('ride:arrived');
    _socket.off('ride:started');
    _socket.off('ride:cancelled');
    super.dispose();
  }

  void _showArrivedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('🛺 रिक्शा आ गई!', style: GoogleFonts.baloo2()),
        content: Text('ड्राइवर को OTP बताएँ: ${ref.read(activeRideProvider)?.otp ?? ''}',
            style: GoogleFonts.hind(fontSize: 18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ठीक है')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ride = ref.watch(activeRideProvider);
    final driver = ride?.driver;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('ड्राइवर मिल गया'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            await RickboApi().cancelRide(widget.rideId);
            ref.read(activeRideProvider.notifier).clear();
            if (mounted) context.go('/');
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [blue, blueDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [blueShadow()],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.person, size: 40, color: blue),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(driver?['name']?.toString() ?? 'ड्राइवर',
                                  style: GoogleFonts.baloo2(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Row(children: [
                                const Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
                                const SizedBox(width: 4),
                                Text('${driver?['ratingAvg'] ?? '4.8'}',
                                    style: GoogleFonts.hind(color: Colors.white, fontSize: 14)),
                              ]),
                              const SizedBox(height: 4),
                              Text('📞 ${driver?['phone']?.toString() ?? ''}',
                                  style: GoogleFonts.hind(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        (driver?['rickshawNumber']?.toString() ?? 'रिक्शा नंबर').toUpperCase(),
                        style: GoogleFonts.baloo2(color: blue, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OTP (ड्राइवर को बताएँ जब रिक्शा पहुँचे)',
                        style: GoogleFonts.hind(color: muted, fontSize: 13)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(4, (i) {
                        final digit = (ride?.otp ?? '----').split('').elementAtOrNull(i) ?? '•';
                        return Container(
                          width: 56, height: 64,
                          decoration: BoxDecoration(
                            color: tintCyan,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cyan, width: 1.5),
                          ),
                          child: Center(
                            child: Text(digit,
                                style: GoogleFonts.baloo2(fontSize: 28, fontWeight: FontWeight.w800, color: blue)),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(children: [
                      Text('₹${ride?.fare ?? 0}', style: GoogleFonts.baloo2(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
                      Text('पक्का किराया', style: GoogleFonts.hind(fontSize: 11, color: muted)),
                    ]),
                    Container(width: 1, height: 30, color: line),
                    Column(children: [
                      const Icon(Icons.location_on, color: cyan, size: 28),
                      const SizedBox(height: 4),
                      Text(ride?.toZone ?? '—', style: GoogleFonts.hind(fontSize: 13, fontWeight: FontWeight.w700)),
                      Text('गंतव्य', style: GoogleFonts.hind(fontSize: 11, color: muted)),
                    ]),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showShareDialog(),
                  icon: const Icon(Icons.share, color: blue),
                  label: Text('सफ़र शेयर करें',
                      style: GoogleFonts.baloo2(color: blue, fontSize: 16, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: blue, width: 1.5),
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('सफ़र शेयर लिंक', style: GoogleFonts.baloo2()),
        content: Text('rickbo://ride/${widget.rideId}\n\n(Phase 3 में web पर लाइव ट्रैकिंग लिंक बनेगा)',
            style: GoogleFonts.hind()),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ठीक है'))],
      ),
    );
  }
}