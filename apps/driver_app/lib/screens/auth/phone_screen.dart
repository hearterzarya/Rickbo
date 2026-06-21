import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rickbo_core/rickbo_core.dart';
import '../../providers/auth_provider.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final d = _ctrl.text.trim();
    if (d.length != 10) {
      _toast('10 अंकों का नंबर डालें');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await RickboApi().startTestOtp(phone: '+91$d', role: 'driver');
      if (!mounted) return;
      setState(() => _loading = false);
      context.push('/auth/otp', extra: {
        'phone': '+91$d',
        'role': 'driver',
        'devOtp': res['devOtp'] as String? ?? '',
      });
    } catch (_) {
      setState(() => _loading = false);
      _toast('Server से बात नहीं हो पाई');
    }
  }

  /// One-tap test login (DEBUG builds only). Skips Firebase AND the OTP
  /// screen — calls /auth/test-otp which returns a JWT directly, then
  /// routes to home or the registration screen the same way the OTP
  /// screen does. Lets the emulator reach a working home in one tap.
  Future<void> _quickTestLogin() async {
    final d = _ctrl.text.trim();
    if (d.length != 10) {
      _toast('10 अंकों का नंबर डालें');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await RickboApi().loginTestOtp(
        phone: '+91$d',
        role: 'driver',
      );
      final token = res['token'] as String;
      final isNew = res['isNew'] as bool? ?? false;
      await ApiClient().setToken(token);
      ref.read(driverAuthProvider.notifier).setAuthenticated(token);
      if (!mounted) return;
      context.go(isNew ? '/auth/register' : '/');
    } catch (_) {
      _toast('Server से बात नहीं हो पाई');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              Center(
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(color: tintCyan, shape: BoxShape.circle),
                  child: const Icon(Icons.electric_rickshaw, size: 60, color: blue),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text('नमस्ते ड्राइवर!', style: GoogleFonts.baloo2(fontSize: 28, fontWeight: FontWeight.w800, color: ink)),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text('अपना मोबाइल नंबर डालें', style: GoogleFonts.hind(color: muted, fontSize: 16)),
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                    decoration: BoxDecoration(
                      border: Border.all(color: line, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('+91',
                        style: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.w700, color: ink)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      style: GoogleFonts.baloo2(fontSize: 20, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: 'मोबाइल नंबर',
                        labelStyle: GoogleFonts.hind(color: muted),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(onPressed: _sendOtp, child: const Text('OTP भेजें')),
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _quickTestLogin,
                  icon: const Icon(Icons.flash_on, size: 18),
                  label: const Text('टेस्ट लॉगिन (debug)'),
                ),
              ],
              const Spacer(),
              Center(
                child: GestureDetector(
                  onTap: () => context.push('/dev-settings'),
                  child: Text('Dev Settings',
                      style: GoogleFonts.hind(
                          color: muted, fontSize: 13, decoration: TextDecoration.underline)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}