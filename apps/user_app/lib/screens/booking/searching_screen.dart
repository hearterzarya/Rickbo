import 'dart:async';
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
  Timer? _ticker;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketProvider);
    _attachListeners();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        final ride = ref.read(activeRideProvider);
        _secondsLeft = ride?.shareDeadline != null
            ? ride!.shareDeadline!.difference(DateTime.now()).inSeconds.clamp(0, 9999)
            : 0;
      });
      // If SHARE window expired without a match → show fallback prompt
      if (_secondsLeft == 0 && ref.read(activeRideProvider)?.mode == 'SHARE' && ref.read(activeRideProvider)?.status == 'REQUESTED') {
        // Server should already have cancelled; but just in case, show prompt
        _showShareWindowEnded();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _socket.off('ride:matched');
    _socket.off('ride:no-driver');
    _socket.off('ride:cancelled');
    _socket.off('ride:group-joined');
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

    _socket.on('ride:group-joined', (data) {
      // Driver notification — passengers don't see this
    });

    _socket.on('ride:no-driver', (data) {
      if (data is! Map) return;
      final id = data['rideId'] as String?;
      if (id != widget.rideId) return;
      if (!mounted) return;
      // For SHARE: this is the end of the 2-min window. Show the 3-button fallback.
      final ride = ref.read(activeRideProvider);
      if (ride?.mode == 'SHARE') {
        _showShareWindowEnded();
        return;
      }
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

  void _showShareWindowEnded() {
    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text('2 मिनट हो गए', style: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 8),
              Text('कोई और सवारी नहीं मिली। अब क्या करें?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hind(color: muted, fontSize: 14)),
              const SizedBox(height: 24),
              _ShareFallback(
                label: 'अकेले ₹25 में बुक करें',
                subtitle: 'पूरी रिक्शा — पक्की बुकिंग',
                icon: Icons.electric_rickshaw,
                color: blue,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final r = await RickboApi().shareAction(widget.rideId, 'SOLO');
                    // After SOLO, server will retry matching as RESERVE
                    ref.read(activeRideProvider.notifier).update((_) => ActiveRide(
                          rideId: r.id,
                          status: r.status,
                          mode: r.mode,
                          fare: r.fare,
                          fromZone: r.fromZone,
                          toZone: r.toZone,
                          shareToken: r.shareToken,
                          shareGroupId: r.shareGroupId,
                          shareDeadline: r.shareDeadline,
                        ));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('₹25 पर अकेले बुक — रिक्शा ढूंढ रहे हैं')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('कुछ गड़बड़ हो गई')),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _ShareFallback(
                label: '1 मिनट और इंतज़ार',
                subtitle: 'शायद कोई और सवारी मिल जाए',
                icon: Icons.timer_outlined,
                color: greenBright,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await RickboApi().shareAction(widget.rideId, 'EXTEND');
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('1 मिनट और देखते हैं')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('कुछ गड़बड़ हो गई')),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _ShareFallback(
                label: 'रद्द करें',
                subtitle: 'कोई बुकिंग नहीं',
                icon: Icons.close,
                color: red,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await RickboApi().shareAction(widget.rideId, 'CANCEL');
                    ref.read(activeRideProvider.notifier).clear();
                    if (mounted) context.go('/');
                  } catch (_) {}
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ride = ref.watch(activeRideProvider);
    final isShare = ride?.mode == 'SHARE';
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            try {
              if (isShare) {
                await RickboApi().shareAction(widget.rideId, 'CANCEL');
              } else {
                await RickboApi().cancelRide(widget.rideId);
              }
            } catch (_) {}
            ref.read(activeRideProvider.notifier).clear();
            if (mounted) context.go('/');
          },
        ),
        title: Text(isShare ? 'साझा सवारी ढूंढ रहे हैं' : 'रिक्शा ढूंढ रहे हैं'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RickshawPulse(isShare: isShare),
              const SizedBox(height: 32),
              Text(
                isShare ? 'साझा सवारी ढूंढ रहे हैं...' : 'रिक्शा ढूंढ रहे हैं...',
                style: GoogleFonts.baloo2(fontSize: 24, fontWeight: FontWeight.w800, color: ink),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${ride?.fare ?? 0} ${isShare ? "प्रति सवारी" : "पक्का किराया"}',
                style: GoogleFonts.hind(fontSize: 16, color: muted),
              ),
              const SizedBox(height: 32),
              if (isShare && _secondsLeft > 0) ...[
                _ShareCountdown(seconds: _secondsLeft),
                const SizedBox(height: 12),
                Text('2 मिनट में साझा सवारी मिलेगी',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hind(fontSize: 13, color: muted)),
              ] else
                Column(
                  children: [
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareCountdown extends StatelessWidget {
  final int seconds;
  const _ShareCountdown({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final mm = (seconds ~/ 60).toString().padLeft(1, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: greenBright.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: greenBright.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: greenBright),
          const SizedBox(width: 10),
          Text('बाकी: $mm:$ss',
              style: GoogleFonts.baloo2(
                  fontSize: 22, fontWeight: FontWeight.w800, color: greenBright)),
        ],
      ),
    );
  }
}

class _ShareFallback extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ShareFallback({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
                  Text(subtitle, style: GoogleFonts.hind(fontSize: 12, color: muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: muted),
          ],
        ),
      ),
    );
  }
}

class _RickshawPulse extends StatefulWidget {
  final bool isShare;
  const _RickshawPulse({this.isShare = false});
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
    final color = widget.isShare ? greenBright : cyan;
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
                    border: Border.all(color: color.withOpacity(0.4), width: 2),
                  ),
                ),
              ),
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
                boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 30, spreadRadius: 6)],
              ),
              child: Icon(
                widget.isShare ? Icons.people : Icons.electric_rickshaw,
                size: 56, color: blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
