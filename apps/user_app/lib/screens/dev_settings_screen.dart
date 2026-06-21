import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rickbo_core/rickbo_core.dart';

/// Allows changing the API base URL at runtime.
/// Required for testing on a physical phone (can't reach localhost).
class DevSettingsScreen extends StatefulWidget {
  const DevSettingsScreen({super.key});

  @override
  State<DevSettingsScreen> createState() => _DevSettingsScreenState();
}

class _DevSettingsScreenState extends State<DevSettingsScreen> {
  final _ctrl = TextEditingController();
  String _current = '';
  bool _isLive = false;
  Map<String, dynamic>? _testOtp;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await ApiClient().getBaseUrl();
    setState(() {
      _current = url;
      _ctrl.text = url;
      _isLive = url.contains('railway.app') || url.contains('https://');
    });
  }

  Future<void> _save() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) return;
    await ApiClient().updateBaseUrl(url);
    setState(() {
      _current = url;
      _isLive = url.contains('railway.app') || url.contains('https://');
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API URL अपडेट हो गया!')),
      );
    }
  }

  /// Phase 5: one-tap test login. Only works against dev/live backend that has
  /// the /auth/test-otp/start + /verify endpoints enabled. Hits the backend and
  /// returns the devOtp in the response so the user can copy it.
  Future<void> _quickTestOtp() async {
    final phoneCtrl = TextEditingController(text: '+919876500101');
    final roleCtrl = TextEditingController(text: 'user');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quick Test OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone (+91...)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: roleCtrl,
              decoration: const InputDecoration(labelText: 'Role (user|driver)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _testOtp = null);
    try {
      final api = RickboApi();
      final start = await api.startTestOtp(
        phone: phoneCtrl.text.trim(),
        role: roleCtrl.text.trim(),
      );
      setState(() => _testOtp = start);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP: ${start['devOtp']} (valid 5 min)')),
        );
      }
    } catch (e) {
      if (mounted) HindiError.show(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dev Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current URL:', style: GoogleFonts.hind(color: muted, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              _current,
              style: GoogleFonts.hind(fontSize: 14, fontWeight: FontWeight.w600, color: blue),
            ),
            if (_isLive)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: green.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text('☁️  Live (Railway)', style: GoogleFonts.hind(color: green, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 28),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'New API Base URL',
                hintText: 'http://192.168.1.12:4000',
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _hint('Android emulator', 'http://10.0.2.2:4000'),
            _hint('iOS simulator / web', 'http://127.0.0.1:4000'),
            _hint('Physical phone (LAN)', 'http://<PC-LAN-IP>:4000'),
            _hint('☁️  Live (Railway)', 'https://rickbo-production.up.railway.app'),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _save, child: const Text('Save & Apply')),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 12),
            Text('Quick Test Login', style: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.w700, color: blue)),
            const SizedBox(height: 4),
            Text(
              'Sends a dev OTP to the live backend so you can log in without Firebase.\n'
              'OTP appears in the response — use it on the OTP screen.',
              style: GoogleFonts.hind(color: muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _quickTestOtp,
              icon: const Icon(Icons.flash_on, size: 18),
              label: const Text('Send Test OTP'),
              style: ElevatedButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white),
            ),
            if (_testOtp != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: green.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.vpn_key, color: green, size: 18),
                        const SizedBox(width: 6),
                        Text('OTP: ${_testOtp!['devOtp']}',
                            style: GoogleFonts.baloo2(color: green, fontSize: 22, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18, color: green),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _testOtp!['devOtp'].toString()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('OTP कॉपी हो गया')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _hint(String label, String url) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text('$label: ', style: GoogleFonts.hind(color: muted, fontSize: 13)),
            Text(url, style: GoogleFonts.hind(color: blue, fontSize: 13)),
          ],
        ),
      );
}
