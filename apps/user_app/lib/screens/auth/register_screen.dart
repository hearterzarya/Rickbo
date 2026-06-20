import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rickbo_core/rickbo_core.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('अपना नाम लिखें')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await RickboApi().updateUserMe(name: name);
    } catch (_) {}
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('प्रोफ़ाइल')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('अपना नाम बताइए', style: GoogleFonts.baloo2(fontSize: 28, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 8),
              Text('ताकि ड्राइवर आपको पहचान सके',
                  style: GoogleFonts.hind(color: muted, fontSize: 14)),
              const SizedBox(height: 28),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.hind(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'पूरा नाम',
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