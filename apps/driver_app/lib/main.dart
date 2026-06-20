import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rickbo_core/rickbo_core.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient().init();
  runApp(const ProviderScope(child: RickboDriverApp()));
}

class RickboDriverApp extends ConsumerStatefulWidget {
  const RickboDriverApp({super.key});

  @override
  ConsumerState<RickboDriverApp> createState() => _RickboDriverAppState();
}

class _RickboDriverAppState extends ConsumerState<RickboDriverApp> {
  late final router = buildRouter(ref);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Rickbo Driver',
      theme: rickboTheme(),
      routerConfig: router,
      builder: (ctx, child) => OfferOverlayHost(child: child ?? const SizedBox()),
      debugShowCheckedModeBanner: false,
    );
  }
}