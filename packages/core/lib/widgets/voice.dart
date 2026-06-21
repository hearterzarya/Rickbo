import 'package:flutter_tts/flutter_tts.dart';

/// Phase 5: Hindi voice helper for the driver app.
/// Uses flutter_tts which calls the OS TTS engine (Google TTS on Android, offline).
/// No MP3s to bundle, no file I/O, works without network once the engine is installed.
class RickboVoice {
  RickboVoice._();
  static final RickboVoice instance = RickboVoice._();

  FlutterTts? _tts;
  bool _ready = false;
  bool _muted = false;

  bool get isMuted => _muted;
  set muted(bool v) => _muted = v;

  Future<void> _ensureInit() async {
    if (_ready) return;
    try {
      _tts = FlutterTts();
      await _tts!.setLanguage('hi-IN');
      await _tts!.setSpeechRate(0.5);
      await _tts!.setVolume(1.0);
      await _tts!.setPitch(1.0);
      // Set a Hindi voice if available; on Android the system picks hi-IN from locale.
      _ready = true;
    } catch (_) {
      // If TTS init fails (no engine, no permission), we just silently no-op.
      _ready = false;
    }
  }

  /// Speak [text] in Hindi. No-op if muted, or if TTS init failed.
  Future<void> say(String text) async {
    if (_muted || text.trim().isEmpty) return;
    await _ensureInit();
    if (!_ready || _tts == null) return;
    try {
      await _tts!.stop();
      await _tts!.speak(text);
    } catch (_) {
      // Swallow — never let TTS break the ride flow.
    }
  }

  Future<void> stop() async {
    if (_tts == null) return;
    try { await _tts!.stop(); } catch (_) {}
  }
}
