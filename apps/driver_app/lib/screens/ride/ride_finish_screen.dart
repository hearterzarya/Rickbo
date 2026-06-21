import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rickbo_core/rickbo_core.dart';

class RideFinishScreen extends StatefulWidget {
  final String rideId;
  final int fare;
  final String toZone;
  const RideFinishScreen({super.key, required this.rideId, required this.fare, required this.toZone});

  @override
  State<RideFinishScreen> createState() => _RideFinishScreenState();
}

class _RideFinishScreenState extends State<RideFinishScreen> {
  bool _busy = false;
  bool _sosPressed = false;

  Future<void> _complete() async {
    setState(() => _busy = true);
    try {
      await RickboApi().completeRide(widget.rideId);
      if (!mounted) return;
      // Phase 5: voice prompt on ride completion.
      RickboVoice.instance.say('सफ़र पूरा');
      // Show success then push to rate-user screen.
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: green,
          title: Text('सफ़र पूरा! 🎉', style: GoogleFonts.baloo2(color: Colors.white)),
          content: Text('₹${widget.fare} नकद मिल गए।\nसवारी को रेट करें — 5 सैकंड।',
              style: GoogleFonts.hind(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/ride/rate', extra: {'rideId': widget.rideId});
              },
              child: Text('ठीक है', style: GoogleFonts.baloo2(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) HindiError.show(context, e);
      setState(() => _busy = false);
    }
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
        lat = p.latitude; lng = p.longitude;
      } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('गंतव्य पर हैं')),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [green, Color(0xFF1F7A2E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      boxShadow: [BoxShadow(color: green.withOpacity(0.4), blurRadius: 24, spreadRadius: 6)],
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 80),
                  ),
                  const SizedBox(height: 28),
                  Text(widget.toZone, style: GoogleFonts.baloo2(fontSize: 26, fontWeight: FontWeight.w800, color: ink)),
                  const SizedBox(height: 6),
                  Text('गंतव्य पर पहुँच गए', style: GoogleFonts.hind(color: muted, fontSize: 16)),
                  const SizedBox(height: 36),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: line),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('नकद किराया', style: GoogleFonts.hind(color: muted, fontSize: 15)),
                        Text('₹${widget.fare}', style: GoogleFonts.baloo2(fontSize: 36, fontWeight: FontWeight.w800, color: green)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _busy
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _complete,
                          child: const Text('सफ़र पूरा  ✓'),
                        ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Positioned(
              right: 20, bottom: 20,
              child: GestureDetector(
                onTap: _sosFlow,
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: red,
                    boxShadow: [BoxShadow(color: red.withOpacity(0.4), blurRadius: 16, spreadRadius: 3)],
                  ),
                  child: Center(
                    child: Text('SOS',
                        style: GoogleFonts.baloo2(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
