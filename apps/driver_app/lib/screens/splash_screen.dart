import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    // Phase 5: branded splash — same e-rickshaw yellow + rickshaw icon, "Driver" subtitle.
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFE082), Color(0xFFFFC107)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.electric_rickshaw, size: 84, color: blue),
                ),
                const SizedBox(height: 28),
                Text('Rickbo Driver',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: blue)),
                const SizedBox(height: 8),
                Text('कमाई, बिना कमीशन',
                    style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 48),
                const SizedBox(width: 32, height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3, color: blue)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}