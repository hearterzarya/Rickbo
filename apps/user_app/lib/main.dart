import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rickbo_core/rickbo_core.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient().init();
  // Global error boundaries — every uncaught error gets a Hindi message, never raw stack trace.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  ErrorWidget.builder = (FlutterErrorDetails details) => _HindiErrorScreen(details: details);
  runApp(const ProviderScope(child: RickboUserApp()));
}

class _HindiErrorScreen extends StatelessWidget {
  final FlutterErrorDetails details;
  const _HindiErrorScreen({required this.details});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFFFFF3F3),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: const Text(
          'कुछ गड़बड़ हो गई। ऐप बंद करके फिर खोलें।',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFB00020), fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
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