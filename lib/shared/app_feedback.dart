import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One set of sounds + vibrations for the whole app, so every module feels the same:
///
/// * [scan]    a barcode / QR frame was accepted: system click + medium tick
/// * [success] something was saved or completed: system click + strong tick
/// * [error]   something failed or wasn't found: one long buzz, no click
///
/// Feedback is a nicety: a phone with no vibrator, or any platform error, must
/// never break the flow that triggered it, so every call swallows failures.
class AppFeedback {
  const AppFeedback();

  void scan() {
    _run(() => SystemSound.play(SystemSoundType.click));
    _run(HapticFeedback.mediumImpact);
  }

  void success() {
    _run(() => SystemSound.play(SystemSoundType.click));
    _run(HapticFeedback.heavyImpact);
  }

  void error() => _run(HapticFeedback.vibrate);

  // ponytail: the "sound" is the system click (silent if the phone has touch
  // sounds off); play a short beep asset with an audio package if that's too quiet.
  static void _run(Future<void> Function() action) {
    try {
      action().catchError((_) {});
    } catch (_) {}
  }
}

/// Overridden in tests with a recorder.
final feedbackProvider = Provider<AppFeedback>((_) => const AppFeedback());
