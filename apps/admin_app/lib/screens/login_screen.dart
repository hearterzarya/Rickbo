import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rickbo_core/rickbo_core.dart' hide muted, card, ink;
import '../providers/auth_provider.dart';
import '../theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController(text: '9999000111');
  final _apiUrlCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBaseUrl();
  }

  Future<void> _loadBaseUrl() async {
    final url = await ApiClient().getBaseUrl();
    setState(() => _apiUrlCtrl.text = url);
  }

  Future<void> _saveBaseUrl() async {
    final url = _apiUrlCtrl.text.trim();
    if (url.isEmpty) return;
    await ApiClient().setBaseUrl(url);
    // Verify the live Dio instance actually picked it up.
    final liveUrl = ApiClient().dio.options.baseUrl;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('API URL saved → $liveUrl'),
          duration: const Duration(seconds: 3),
          backgroundColor: liveUrl == url ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  /// One-tap reset for emulator users stuck on a stale Railway URL.
  Future<void> _resetToLocal() async {
    await ApiClient().setBaseUrl('http://10.0.2.2:4000');
    final liveUrl = ApiClient().dio.options.baseUrl;
    setState(() => _apiUrlCtrl.text = liveUrl);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset to $liveUrl'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _login() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10) {
      setState(() => _error = '10 अंकों का phone डालें');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await RickboApi().loginTestOtp(
        phone: '+91$phone',
        role: 'admin',
      );
      final token = res['token'] as String;
      await ref.read(authProvider.notifier).login(token, '+91$phone');
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      setState(() => _error = 'Login नहीं हुआ — API URL ठीक है?\n$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(color: primary.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.shield, color: primary, size: 44),
                  ),
                  const SizedBox(height: 18),
                  Text('Rickbo Admin',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Operations + Safety Control Room',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 13)),
                  const SizedBox(height: 36),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                    decoration: const InputDecoration(
                      counterText: '',
                      labelText: 'Admin phone (+91)',
                      prefixText: '+91 ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text(_error!, style: TextStyle(color: danger, fontSize: 13)),
                    ),
                  const SizedBox(height: 12),
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: _login,
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text('Admin Login'),
                        ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text('API URL', style: TextStyle(color: muted, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _apiUrlCtrl,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(hintText: 'http://10.0.2.2:4000'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Android emulator: 10.0.2.2:4000\nPhysical phone: <PC-LAN-IP>:4000',
                    style: TextStyle(color: muted, fontSize: 11, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: _saveBaseUrl, child: const Text('Save API URL')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _resetToLocal,
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF10B981))),
                          child: const Text('Reset → 10.0.2.2:4000', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}