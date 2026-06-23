import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rickbo_core/rickbo_core.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient().init();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  ErrorWidget.builder = (FlutterErrorDetails details) => const _HindiErrorScreen();
  runApp(const ProviderScope(child: RickboDriverApp()));
}

class _HindiErrorScreen extends StatelessWidget {
  const _HindiErrorScreen();

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