import 'package:flutter_test/flutter_test.dart';
import 'package:tindascan/shared/scan_cooldown.dart';

void main() {
  var t = DateTime(2026);
  ScanCooldown make([Duration d = const Duration(milliseconds: 1500)]) =>
      ScanCooldown(d, () => t);

  setUp(() => t = DateTime(2026));

  test('first scan is accepted, repeats inside the window are not', () {
    final c = make();
    expect(c.accept('A'), isTrue);
    t = t.add(const Duration(milliseconds: 500));
    expect(c.accept('A'), isFalse);
    t = t.add(const Duration(milliseconds: 900)); // 1400 ms
    expect(c.accept('A'), isFalse);
  });

  test('same code is accepted again once the window has passed', () {
    final c = make();
    expect(c.accept('A'), isTrue);
    t = t.add(const Duration(milliseconds: 1500));
    expect(c.accept('A'), isTrue);
  });

  test('the window runs from the last accepted scan, not from sightings', () {
    final c = make();
    expect(c.accept('A'), isTrue); // 0 ms
    for (var i = 0; i < 5; i++) {
      t = t.add(const Duration(milliseconds: 250));
      expect(c.accept('A'), isFalse); // 250..1250 ms, camera re-reading
    }
    t = t.add(const Duration(milliseconds: 250)); // 1500 ms
    expect(c.accept('A'), isTrue);
  });

  test('cooldown is per barcode', () {
    final c = make();
    expect(c.accept('A'), isTrue);
    expect(c.accept('B'), isTrue);
    expect(c.accept('A'), isFalse);
    expect(c.accept('B'), isFalse);
  });

  test('zero cooldown accepts everything', () {
    final c = make(Duration.zero);
    expect(c.accept('A'), isTrue);
    expect(c.accept('A'), isTrue);
  });
}
