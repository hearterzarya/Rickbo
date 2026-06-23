import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:rickbo_core/rickbo_core.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _ecNameCtrl = TextEditingController();
  final _ecPhoneCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ecNameCtrl.dispose();
    _ecPhoneCtrl.dispose();
    super.dispose();
  }

  String? _validatePhone(String input) {
    // Accept 10 digits, optional +91 prefix. Reject anything else.
    final cleaned = input.replaceAll(RegExp(r'[\s\-]'), '');
    final digits = cleaned.startsWith('+91')
        ? cleaned.substring(3)
        : cleaned.startsWith('91') && cleaned.length == 12
            ? cleaned.substring(2)
            : cleaned;
    if (digits.length != 10 || !RegExp(r'^\d{10}$').hasMatch(digits)) {
      return null;
    }
    return digits;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('अपना नाम लिखें')),
      );
      return;
    }
    String? ecPhone;
    final ecPhoneRaw = _ecPhoneCtrl.text.trim();
    if (ecPhoneRaw.isNotEmpty) {
      ecPhone = _validatePhone(ecPhoneRaw);
      if (ecPhone == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('इमरजेंसी नंबर सही नहीं है — 10 अंक')),
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await RickboApi().updateUserMe(
        name: name,
        emergencyContactName: _ecNameCtrl.text.trim().isEmpty
            ? null
            : _ecNameCtrl.text.trim(),
        emergencyContactPhone: ecPhone,
      );
    } catch (_) {}
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('प्रोफ़ाइल')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('अपना नाम बताइए',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 8),
              Text('ताकि ड्राइवर आपको पहचान सके',
                  style: TextStyle(color: muted, fontSize: 14)),
              const SizedBox(height: 28),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'पूरा नाम',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 40),
              Text('इमरजेंसी संपर्क',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 8),
              Text('SOS दबाने पर इन्हें SMS जाएगा — परिवार / दोस्त',
                  style: TextStyle(color: muted, fontSize: 14)),
              const SizedBox(height: 20),
              TextField(
                controller: _ecNameCtrl,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'नाम (वैकल्पिक)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ecPhoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d\s+\-]')),
                  LengthLimitingTextInputFormatter(13),
                ],
                style: TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'मोबाइल नंबर (10 अंक)',
                  hintText: '9876543210',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              _saving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(onPressed: _save, child: const Text('सेव करें')),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : () => context.go('/'),
                  child: Text(
                    'बाद में जोड़ूँगा',
                    style: TextStyle(color: muted, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}