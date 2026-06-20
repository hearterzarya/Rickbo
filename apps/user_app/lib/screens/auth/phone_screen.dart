import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rickbo_core/rickbo_core.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final digits = _ctrl.text.trim();
    if (digits.length != 10) {
      _showError('10 अंकों का नंबर डालें');
      return;
    }
    setState(() => _loading = true);
    try {
      // Dev/Test flow: ask backend for an OTP — no Firebase needed.
      final res = await RickboApi().startTestOtp(
        phone: '+91$digits',
        role: 'user',
      );
      if (!mounted) return;
      setState(() => _loading = false);
      context.push('/auth/otp', extra: {
        'phone': '+91$digits',
        'role': 'user',
        'devOtp': res['devOtp'] as String? ?? '',
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError('Server से connect नहीं हो सका — Dev Settings में URL ठीक करें');
    }
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text('नमस्ते! 👋', style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 8),
              Text('अपना मोबाइल नंबर डालें',
                  style: GoogleFonts.hind(fontSize: 16, color: muted)),
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
                        style: GoogleFonts.baloo2(
                            fontSize: 18, fontWeight: FontWeight.w700, color: ink)),
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
                  : ElevatedButton(
                      onPressed: _sendOtp,
                      child: const Text('OTP भेजें'),
                    ),
              const Spacer(),
              Center(
                child: GestureDetector(
                  onTap: () => context.push('/dev-settings'),
                  child: Text('Dev Settings',
                      style: GoogleFonts.hind(
                        color: muted,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      )),
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