import 'item.dart';

class CartLine {
  const CartLine({
    required this.barcode,
    required this.name,
    required this.unitPriceCents,
    this.qty = 1,
  });

  final String barcode;
  final String name;
  final int unitPriceCents;
  final int qty;

  int get totalCents => unitPriceCents * qty;

  CartLine withQty(int qty) => CartLine(
    barcode: barcode,
    name: name,
    unitPriceCents: unitPriceCents,
    qty: qty,
  );
}

/// Immutable cart: every change returns a new [Cart], which suits Riverpod state.
class Cart {
  const Cart([this.lines = const []]);

  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;

  /// Always computed from the lines, never stored.
  int get totalCents => lines.fold(0, (sum, l) => sum + l.totalCents);

  /// New line with qty 1, or +1 if the barcode is already in the cart.
  /// The price is captured when the line is first added.
  Cart add(Item item) => lines.any((l) => l.barcode == item.barcode)
      ? increment(item.barcode)
      : Cart([
          ...lines,
          CartLine(
            barcode: item.barcode,
            name: item.name,
            unitPriceCents: item.priceCents,
          ),
        ]);

  Cart increment(String barcode) => _change(barcode, 1);

  /// Removes the line when qty reaches 0.
  Cart decrement(String barcode) => _change(barcode, -1);

  Cart remove(String barcode) =>
      Cart(lines.where((l) => l.barcode != barcode).toList());

  Cart clear() => const Cart();

  Cart _change(String barcode, int delta) => Cart([
    for (final l in lines)
      if (l.barcode != barcode)
        l
      else if (l.qty + delta > 0)
        l.withQty(l.qty + delta),
  ]);
}
