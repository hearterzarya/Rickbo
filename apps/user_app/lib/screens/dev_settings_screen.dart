import 'package:flutter/material.dart';
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
    });
  }

  Future<void> _save() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) return;
    await ApiClient().updateBaseUrl(url);
    setState(() => _current = url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API URL अपडेट हो गया!')),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dev Settings')),
      body: Padding(
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
            const SizedBox(height: 28),
            ElevatedButton(onPressed: _save, child: const Text('Save & Apply')),
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
