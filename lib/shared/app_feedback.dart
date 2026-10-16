import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Plays `assets/sounds/<name>.wav`.
typedef Beep = Future<void> Function(String name);

/// One set of sounds + vibrations for the whole app, so every module feels the same:
///
/// * [scan]    a barcode / QR frame was accepted: short beep + medium tick
/// * [success] something was saved or completed: rising two-note beep + strong tick
/// * [error]   something failed or wasn't found: low buzz + one long vibration
///
/// Feedback is a nicety: a phone with no vibrator, or any platform error, must
/// never break the flow that triggered it, so every call swallows failures.
class AppFeedback {
  const AppFeedback({this.beep = _playAsset});

  /// Replaced in tests so no audio plugin is needed.
  final Beep beep;

  void scan() {
    _run(() => beep('scan'));
    _run(HapticFeedback.mediumImpact);
  }

  void success() {
    _run(() => beep('success'));
    _run(HapticFeedback.heavyImpact);
  }

  void error() {
    _run(() => beep('error'));
    _run(HapticFeedback.vibrate);
  }

  static void _run(Future<void> Function() action) {
    try {
      action().catchError((_) {});
    } catch (_) {}
  }
}

/// Plays on the media volume, so a muted media volume is silent (vibration
/// still works). Doesn't take audio focus, so music keeps playing underneath.
final _player = AudioPlayer()
  ..setAudioContext(
    AudioContext(
      android: const AudioContextAndroid(
        audioFocus: AndroidAudioFocus.none,
        usageType: AndroidUsageType.assistanceSonification,
        contentType: AndroidContentType.sonification,
      ),
    ),
  )
  ..setPlayerMode(PlayerMode.lowLatency);

Future<void> _playAsset(String name) =>
    _player.play(AssetSource('sounds/$name.wav'));

/// Overridden in tests with a recorder.
final feedbackProvider = Provider<AppFeedback>((_) => const AppFeedback());
