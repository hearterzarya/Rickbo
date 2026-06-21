import 'dart:async';
import 'package:flutter/services.dart';
import 'voice.dart';

/// Triple-alert for high-importance ride events (incoming offer, SOS, etc).
///
/// Fires all three in parallel so the driver can't miss it even in a noisy
/// environment or with the phone in their pocket:
///   1. Pattern vibration: 4 short bursts with 200ms gaps
///   2. System alert sound: the OS-level "alert" / "alarm" tone
///   3. Hindi TTS voice: speaks [text] via RickboVoice
///
/// All three are best-effort. A failure on any one is swallowed — we never
/// want an alert helper to break the ride flow.
class RideAlert {
  RideAlert._();

  /// Fire pattern vibration + system sound + Hindi voice in parallel.
  static Future<void> urgent(String text) async {
    // Fire-and-forget. Each call is its own async; we don't await them serially.
    unawaited(_patternVibrate());
    unawaited(_systemSound());
    unawaited(RickboVoice.instance.say(text));
  }

  /// Fire only vibration (e.g. for non-critical nudges).
  static Future<void> nudge() async {
    unawaited(_patternVibrate());
  }

  /// 4 short vibrations, 200ms apart, then settle for 1s. Repeats twice for
  /// a total of 3 cycles (~6s) — long enough to be noticed, short enough to
  /// not be annoying.
  static Future<void> _patternVibrate() async {
    try {
      for (int cycle = 0; cycle < 3; cycle++) {
        for (int i = 0; i < 4; i++) {
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 200));
        }
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    } catch (_) {
      // HapticFeedback throws on emulators that don't support it.
    }
  }

  /// Loud system alert sound. Android: ALERT_TRIGGER. iOS: alarm sound.
  static Future<void> _systemSound() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }
}
