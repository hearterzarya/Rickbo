import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rickbo_core/rickbo_core.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.listenManual<DriverAuthState>(driverAuthProvider, (prev, next) {
        if (_navigated) return;
        if (next.token != null) {
          _navigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final hasRickshaw = (next.me?.rickshawNumber ?? '').isNotEmpty;
            context.go(hasRickshaw ? '/' : '/auth/register');
          });
        }
      }, fireImmediately: true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_navigated) return;
        final st = ref.read(driverAuthProvider);
        if (st.token == null) {
          _navigated = true;
          if (mounted) context.go('/auth/phone');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tintCyan,
                boxShadow: [blueShadow(opacity: 0.35, blurRadius: 30)],
              ),
              child: const Icon(Icons.electric_rickshaw, size: 70, color: blue),
            ),
            const SizedBox(height: 24),
            Text('Rickbo Driver', style: GoogleFonts.baloo2(fontSize: 36, fontWeight: FontWeight.w800, color: blue)),
            const SizedBox(height: 6),
            Text('कमाई, बिना कमीशन', style: GoogleFonts.hind(color: muted, fontSize: 14)),
            const SizedBox(height: 32),
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          ],
        ),
      ),
    );
  }
}