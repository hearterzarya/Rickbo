import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  /// One-tap test login (DEBUG builds only). Skips Firebase AND the OTP
  /// screen — calls /auth/test-otp which returns a JWT directly, then
  /// routes to home or the registration screen the same way the OTP
  /// screen does. Lets the emulator reach a working home in one tap.
  Future<void> _quickTestLogin() async {
    final digits = _ctrl.text.trim();
    if (digits.length != 10) {
      _showError('10 अंकों का नंबर डालें');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await RickboApi().loginTestOtp(
        phone: '+91$digits',
        role: 'user',
      );
      final token = res['token'] as String;
      final isNew = res['isNew'] as bool? ?? false;
      await ApiClient().setToken(token);
      ref.read(authProvider.notifier).setAuthenticated(token, isNew: isNew);
      if (!mounted) return;
      context.go(isNew ? '/auth/register' : '/');
    } catch (e) {
      _showError('Server से connect नहीं हो सका — Dev Settings में URL ठीक करें');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('ध्यान दें', style: TextStyle()),
        content: Text(msg, style: TextStyle(fontSize: 16)),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text('नमस्ते! 👋', style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 8),
              Text('अपना मोबाइल नंबर डालें',
                  style: TextStyle(fontSize: 16, color: muted)),
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
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700, color: ink)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: 'मोबाइल नंबर',
                        labelStyle: TextStyle(color: muted),
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
                      style: TextStyle(
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