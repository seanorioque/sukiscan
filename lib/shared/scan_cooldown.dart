/// Per-barcode cooldown: after a code is accepted, the same code is rejected
/// until [duration] has passed. Other codes are unaffected.
///
/// The window runs from the last *accepted* scan (not the last sighting), so
/// scanning three identical cans 2 s apart adds all three, while a camera
/// re-reading one can every frame adds it once per window.
class ScanCooldown {
  ScanCooldown(this.duration, [DateTime Function()? now])
    : _now = now ?? DateTime.now;

  final Duration duration;
  final DateTime Function() _now;
  final _lastAccepted = <String, DateTime>{};

  bool accept(String code) {
    final now = _now();
    final last = _lastAccepted[code];
    if (last != null && now.difference(last) < duration) return false;
    _lastAccepted[code] = now;
    return true;
  }
}
