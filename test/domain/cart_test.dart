import 'package:flutter_test/flutter_test.dart';
import 'package:tindascan/domain/cart.dart';
import 'package:tindascan/domain/item.dart';

void main() {
  const noodles = Item(barcode: 'A', name: 'Noodles', priceCents: 1500);
  const gum = Item(barcode: 'B', name: 'Gum', priceCents: 250);

  test('empty cart totals zero', () {
    expect(const Cart().isEmpty, isTrue);
    expect(const Cart().totalCents, 0);
  });

  test('add creates a line, adding again is +1', () {
    final cart = const Cart().add(noodles).add(noodles);
    expect(cart.lines, hasLength(1));
    expect(cart.lines.single.qty, 2);
    expect(cart.totalCents, 3000);
  });

  test('lines keep the order items were first added', () {
    final cart = const Cart().add(noodles).add(gum).add(noodles);
    expect(cart.lines.map((l) => l.barcode), ['A', 'B']);
  });

  test('increment and decrement change qty', () {
    var cart = const Cart().add(noodles).increment('A').increment('A');
    expect(cart.lines.single.qty, 3);
    cart = cart.decrement('A');
    expect(cart.lines.single.qty, 2);
  });

  test('decrement to zero removes the line', () {
    final cart = const Cart().add(noodles).add(gum).decrement('A');
    expect(cart.lines.map((l) => l.barcode), ['B']);
  });

  test('unknown barcode is a no-op', () {
    final cart = const Cart().add(noodles);
    expect(cart.increment('Z').totalCents, 1500);
    expect(cart.decrement('Z').totalCents, 1500);
    expect(cart.remove('Z').totalCents, 1500);
  });

  test('remove drops the whole line, clear empties the cart', () {
    final cart = const Cart().add(noodles).add(noodles).add(gum);
    expect(cart.remove('A').lines.map((l) => l.barcode), ['B']);
    expect(cart.clear().isEmpty, isTrue);
  });

  test('total is exact integer centavos across lines', () {
    final cart = const Cart().add(noodles).add(gum).add(gum).add(gum);
    expect(cart.totalCents, 1500 + 3 * 250); // 2250
  });

  test('cart is immutable: changes return a new cart', () {
    const original = Cart();
    final changed = original.add(noodles);
    expect(original.isEmpty, isTrue);
    expect(changed.isEmpty, isFalse);
  });
}
