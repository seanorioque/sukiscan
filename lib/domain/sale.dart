/// One finished sale, as listed in the purchase history.
class SaleSummary {
  const SaleSummary({
    required this.id,
    required this.createdAt,
    required this.totalCents,
    required this.itemCount,
    this.cashCents,
  });

  final String id;
  final int createdAt; // epoch ms
  final int totalCents;

  /// Cash handed over, if it was entered at checkout.
  final int? cashCents;

  /// Total quantity sold (not the number of lines).
  final int itemCount;

  int? get changeCents => cashCents == null ? null : cashCents! - totalCents;
}

/// One line of a sale, as it was when sold (name and price are snapshots).
class SaleLine {
  const SaleLine({
    required this.barcode,
    required this.name,
    required this.unitPriceCents,
    required this.qty,
  });

  final String barcode;
  final String name;
  final int unitPriceCents;
  final int qty;

  int get totalCents => unitPriceCents * qty;
}
