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
    // Listen once for the first auth state and navigate.
    Future.microtask(() {
      ref.listenManual<AuthState>(authProvider, (prev, next) {
        if (_navigated) return;
        if (next.token != null) {
          _navigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/');
          });
        }
      }, fireImmediately: true);
      // After 800 ms if still no token, go to phone screen.
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_navigated) return;
        final st = ref.read(authProvider);
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
            Text('Rickbo', style: GoogleFonts.baloo2(fontSize: 42, fontWeight: FontWeight.w800, color: blue)),
            const SizedBox(height: 6),
            Text('रिक्शा, बस एक टैप', style: GoogleFonts.hind(color: muted, fontSize: 14)),
            const SizedBox(height: 32),
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          ],
        ),
      ),
    );
  }
}