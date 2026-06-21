import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rickbo_core/rickbo_core.dart';

class RideOtpScreen extends StatefulWidget {
  final String rideId;
  final int fare;
  final String toZone;
  final String userName;
  const RideOtpScreen({super.key, required this.rideId, required this.fare, required this.toZone, required this.userName});

  @override
  State<RideOtpScreen> createState() => _RideOtpScreenState();
}

class _RideOtpScreenState extends State<RideOtpScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_ctrl.text.trim().length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('4 अंकों का OTP डालें')));
      return;
    }
    setState(() => _busy = true);
    try {
      await RickboApi().startRide(widget.rideId, _ctrl.text.trim());
      if (!mounted) return;
      // Phase 5: voice prompt on ride start.
      RickboVoice.instance.say('सफ़र शुरू');
      context.go('/ride/finish', extra: {
        'rideId': widget.rideId,
        'fare': widget.fare,
        'toZone': widget.toZone,
      });
    } catch (e) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP गलत है')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('सवारी शुरू करें')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text('यात्री से OTP पूछें', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 8),
              Text('सही OTP आने पर ही सफ़र शुरू करें',
                  style: TextStyle(color: muted, fontSize: 14)),
              const SizedBox(height: 40),
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: 22),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '0 0 0 0',
                  hintStyle: TextStyle(color: line, fontSize: 44, letterSpacing: 22),
                ),
              ),
              const SizedBox(height: 24),
              _busy
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _start,
                      child: const Text('OTP सही है — सफ़र शुरू'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}