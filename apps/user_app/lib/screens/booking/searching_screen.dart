import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rickbo_core/rickbo_core.dart';
import '../../providers/ride_provider.dart';

class SearchingScreen extends ConsumerStatefulWidget {
  final String rideId;
  const SearchingScreen({super.key, required this.rideId});

  @override
  ConsumerState<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends ConsumerState<SearchingScreen> {
  late final RickboSocket _socket;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketProvider);
    _attachListeners();
  }

  @override
  void dispose() {
    _socket.off('ride:matched');
    _socket.off('ride:no-driver');
    _socket.off('ride:cancelled');
    super.dispose();
  }

  void _attachListeners() {
    _socket.on('ride:matched', (data) {
      if (data is! Map) return;
      final id = data['rideId'] as String?;
      if (id != widget.rideId) return;
      ref.read(activeRideProvider.notifier).update((r) => r.copyWith(
            status: 'MATCHED',
            otp: data['otp'] as String?,
            driver: data['driver'] as Map<String, dynamic>?,
            fare: (data['fare'] as num?)?.toInt() ?? r.fare,
          ));
      if (!mounted) return;
      context.go('/booking/assigned', extra: {'rideId': widget.rideId});
    });

    _socket.on('ride:no-driver', (data) {
      if (data is! Map) return;
      final id = data['rideId'] as String?;
      if (id != widget.rideId) return;
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('कोई रिक्शा नहीं मिली', style: GoogleFonts.baloo2()),
          content: Text('अभी कोई रिक्शा खाली नहीं है। थोड़ी देर बाद दोबारा कोशिश करें।',
              style: GoogleFonts.hind()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(activeRideProvider.notifier).clear();
                context.go('/');
              },
              child: const Text('ठीक है'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ride = ref.watch(activeRideProvider);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            await RickboApi().cancelRide(widget.rideId);
            ref.read(activeRideProvider.notifier).clear();
            if (mounted) context.go('/');
          },
        ),
        title: const Text('रिक्शा ढूंढ रहे हैं'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RickshawPulse(),
              const SizedBox(height: 32),
              Text('रिक्शा ढूंढ रहे हैं...',
                  style: GoogleFonts.baloo2(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 8),
              Text('₹${ride?.fare ?? 0} • पक्का किराया',
                  style: GoogleFonts.hind(fontSize: 16, color: muted)),
              const SizedBox(height: 32),
              SizedBox(
                width: 220,
                child: LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: line,
                  color: cyan,
                ),
              ),
              const SizedBox(height: 12),
              Text('20-20 सेकंड में अगले ड्राइवर को ऑफर जाएगा',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hind(fontSize: 13, color: muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RickshawPulse extends StatefulWidget {
  @override
  State<_RickshawPulse> createState() => _RickshawPulseState();
}

class _RickshawPulseState extends State<_RickshawPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => SizedBox(
        width: 200, height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Opacity(
                opacity: (1 - (_c.value + i / 3) % 1).clamp(0.0, 1.0),
                child: Container(
                  width: 200 - i * 40,
                  height: 200 - i * 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cyan.withOpacity(0.4), width: 2),
                  ),
                ),
              ),
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cyan.withOpacity(0.12),
                boxShadow: [BoxShadow(color: cyan.withOpacity(0.35), blurRadius: 30, spreadRadius: 6)],
              ),
              child: const Icon(Icons.electric_rickshaw, size: 56, color: blue),
            ),
          ],
        ),
      ),
    );
  }
}