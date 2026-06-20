import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rickbo_core/rickbo_core.dart';
import '../../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  final String role;
  final String devOtp;
  const OtpScreen({
    super.key,
    required this.phone,
    required this.role,
    required this.devOtp,
  });

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
      _showError('6 अंकों का OTP डालें');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await RickboApi().verifyTestOtp(
        phone: widget.phone,
        otp: otp,
        role: widget.role,
      );
      final token = res['token'] as String;
      final isNew = res['isNew'] as bool? ?? false;
      await ApiClient().setToken(token);
      ref.read(authProvider.notifier).setAuthenticated(token, isNew: isNew);
      if (!mounted) return;
      context.go(isNew ? '/auth/register' : '/');
    } catch (e) {
      setState(() => _loading = false);
      _showError('OTP गलत है — दोबारा कोशिश करें');
    }
  }

  void _autoFill() {
    _ctrl.text = widget.devOtp;
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('ध्यान दें', style: GoogleFonts.baloo2()),
        content: Text(msg, style: GoogleFonts.hind(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ठीक है')),
        ],
      ),
    );
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
            const SizedBox(height: 16),
            Text('OTP आया?', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 8),
            Text('${widget.phone} पर 6 अंकों का OTP भेजा गया',
                style: GoogleFonts.hind(fontSize: 15, color: muted)),
            const SizedBox(height: 40),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 12),
              decoration: InputDecoration(
                counterText: '',
                hintText: '● ● ● ● ● ●',
                hintStyle: GoogleFonts.hind(color: line, fontSize: 22, letterSpacing: 8),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.devOtp.isNotEmpty)
              Center(
                child: TextButton(
                  onPressed: _autoFill,
                  child: Text(
                    '🪄 डेव OTP भरें (${widget.devOtp})',
                    style: GoogleFonts.hind(color: cyan, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _loading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(onPressed: _verify, child: const Text('जाँचें और आगे बढ़ें')),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => context.pop(),
                child: Text('नंबर बदलें / दोबारा OTP भेजें',
                    style: GoogleFonts.hind(color: blue, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}