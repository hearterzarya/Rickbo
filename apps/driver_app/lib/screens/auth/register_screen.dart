import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rickbo_core/rickbo_core.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _rickshawCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rickshawCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final rick = _rickshawCtrl.text.trim().toUpperCase();
    if (name.isEmpty || rick.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('नाम और रिक्शा नंबर ज़रूरी है')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final me = await RickboApi().updateDriverMe(name: name, rickshawNumber: rick);
      ref.read(driverAuthProvider.notifier).setProfile(me);
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('सेव नहीं हो सका — दोबारा कोशिश करें')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('प्रोफ़ाइल पूरा करें')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text('अपनी जानकारी', style: GoogleFonts.baloo2(fontSize: 28, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 8),
              Text('ताकि यात्री आपको पहचान सकें',
                  style: GoogleFonts.hind(color: muted, fontSize: 14)),
              const SizedBox(height: 28),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.hind(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'आपका नाम',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _rickshawCtrl,
                textCapitalization: TextCapitalization.characters,
                style: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 3),
                decoration: const InputDecoration(
                  labelText: 'रिक्शा नंबर (UP16 XX XXXX)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              _saving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(onPressed: _save, child: const Text('सेव करें')),
            ],
          ),
        ),
      ),
    );
  }
}