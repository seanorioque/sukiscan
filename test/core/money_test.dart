import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/core/money.dart';

void main() {
  test('parseCents accepts valid input', () {
    expect(parseCents('12.5'), 1250);
    expect(parseCents('12'), 1200);
    expect(parseCents('0.05'), 5);
    expect(parseCents(' 1,234.50 '), 123450);
    expect(parseCents('19.99'), 1999); // would be 1998 via double math
  });

  test('parseCents rejects invalid input', () {
    for (final s in ['', ' ', 'abc', '-5', '1.234', '1.', '.5', '1..2', '₱5']) {
      expect(parseCents(s), isNull, reason: s);
    }
  });

  test('formatCents', () {
    expect(formatCents(1250), '₱12.50');
    expect(formatCents(5), '₱0.05');
    expect(formatCents(123450), '₱1,234.50');
    expect(formatCents(0), '₱0.00');
    expect(formatCents(-250), '-₱2.50');
  });
}
