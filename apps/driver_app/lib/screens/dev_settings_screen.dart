// Mirrors user_app dev settings. Kept as its own file so each app can diverge later.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rickbo_core/rickbo_core.dart';

class DevSettingsScreen extends StatefulWidget {
  const DevSettingsScreen({super.key});

  @override
  State<DevSettingsScreen> createState() => _DevSettingsScreenState();
}

class _DevSettingsScreenState extends State<DevSettingsScreen> {
  final _ctrl = TextEditingController();
  bool _saving = false;
  String _hint = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cur = await ApiClient().getBaseUrl();
    setState(() {
      _ctrl.text = cur;
      _hint = _autoHint(cur);
    });
  }

  String _autoHint(String url) {
    if (url.contains('10.0.2.2')) return 'Android emulator';
    if (url.contains('127.0.0.1') || url.contains('localhost')) return 'iOS sim / web';
    if (url.contains('192.168.')) return 'Physical phone (LAN)';
    if (url.contains('railway.app')) return '☁️  Live (Railway)';
    return '';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ApiClient().setBaseUrl(_ctrl.text.trim());
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API URL सेव हो गया')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dev Settings')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text('Backend URL', style: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 8),
          Text('Backend कहाँ सुन रहा है?',
              style: GoogleFonts.hind(color: muted, fontSize: 14)),
          const SizedBox(height: 20),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: GoogleFonts.hind(fontSize: 16),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Base URL',
              hintText: 'http://192.168.1.12:4000',
              helperText: _hint,
            ),
          ),
          const SizedBox(height: 16),
          _Hint(text: 'Android emulator → http://10.0.2.2:4000'),
          _Hint(text: 'iOS sim / web → http://127.0.0.1:4000'),
          _Hint(text: 'Physical phone → PC के LAN IP पे (http://192.168.x.x:4000)'),
          _Hint(text: '☁️  Live (Railway) → https://rickbo-production.up.railway.app'),
          const Spacer(),
          ElevatedButton(onPressed: _saving ? null : _save, child: const Text('सेव')),
        ]),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('• $text', style: GoogleFonts.hind(color: muted, fontSize: 13)),
    );
  }
}