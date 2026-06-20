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