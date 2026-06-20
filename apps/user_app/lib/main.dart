import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rickbo_core/rickbo_core.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient().init();
  runApp(const ProviderScope(child: RickboUserApp()));
}

class RickboUserApp extends ConsumerStatefulWidget {
  const RickboUserApp({super.key});

  @override
  ConsumerState<RickboUserApp> createState() => _RickboUserAppState();
}

class _RickboUserAppState extends ConsumerState<RickboUserApp> {
  late final router = buildRouter(ref);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Rickbo',
      theme: rickboTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}