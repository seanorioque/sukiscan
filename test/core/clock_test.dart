import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/core/clock.dart';

void main() {
  test('default clock returns current epoch ms', () {
    final c = ProviderContainer();
    final before = DateTime.now().millisecondsSinceEpoch;
    final now = c.read(clockProvider)();
    expect(now, greaterThanOrEqualTo(before));
  });

  test('clock can be overridden', () {
    final c = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(() => 1234)],
    );
    expect(c.read(clockProvider)(), 1234);
  });
}
