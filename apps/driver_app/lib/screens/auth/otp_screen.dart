import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rickbo_core/rickbo_core.dart';
import '../../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  final String devOtp;
  const OtpScreen({super.key, required this.phone, required this.devOtp});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _ctrl.text.trim();
    if (otp.length != 6) {
      _toast('6 अंकों का OTP डालें');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await RickboApi().verifyTestOtp(phone: widget.phone, otp: otp, role: 'driver');
      final token = res['token'] as String;
      await ApiClient().setToken(token);
      final me = await RickboApi().getDriverMe();
      ref.read(driverAuthProvider.notifier).setProfile(me);
      ref.read(driverAuthProvider.notifier).setAuthenticated(token);
      if (!mounted) return;
      // First time? -> register screen to fill rickshaw number.
      final hasRickshaw = (me.rickshawNumber ?? '').isNotEmpty;
      context.go(hasRickshaw ? '/' : '/auth/register');
    } catch (e) {
      setState(() => _loading = false);
      _toast('OTP गलत है');
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OTP जाँचें')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text('OTP आया?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 8),
            Text('${widget.phone} पर 6 अंकों का OTP भेजा गया',
                style: TextStyle(fontSize: 15, color: muted)),
            const SizedBox(height: 40),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 12),
              decoration: InputDecoration(
                counterText: '',
                hintText: '● ● ● ● ● ●',
                hintStyle: TextStyle(color: line, fontSize: 22, letterSpacing: 8),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.devOtp.isNotEmpty)
              Center(
                child: TextButton(
                  onPressed: () => _ctrl.text = widget.devOtp,
                  child: Text('🪄 डेव OTP भरें (${widget.devOtp})',
                      style: TextStyle(color: cyan, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            const SizedBox(height: 16),
            _loading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(onPressed: _verify, child: const Text('जाँचें')),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => context.pop(),
                child: Text('नंबर बदलें', style: TextStyle(color: blue, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}