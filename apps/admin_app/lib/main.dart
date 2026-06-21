import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rickbo_core/rickbo_core.dart';
import 'app/router.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient().init();

  // Convenience for local emulator testing: in debug builds, default the
  // API URL to the local NestJS backend (10.0.2.2 = Android emulator's
  // host machine). This avoids the 404 you get when the saved URL still
  // points at the Railway deploy that doesn't have the admin module.
  if (kDebugMode) {
    final current = await ApiClient().getBaseUrl();
    if (current.contains('railway.app') || current.isEmpty) {
      await ApiClient().setBaseUrl('http://10.0.2.2:4000');
    }
  }

  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Rickbo Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      routerConfig: router,
    );
  }
}