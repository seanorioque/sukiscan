class Item {
  const Item({
    required this.barcode,
    required this.name,
    required this.priceCents,
    this.stockQty = 0,
    this.updatedAt = 0,
    this.deleted = false,
  });

  final String barcode;
  final String name;
  final int priceCents;
  final int stockQty;
  final int updatedAt;
  final bool deleted;

  factory Item.fromMap(Map<String, Object?> m) => Item(
    barcode: m['barcode'] as String,
    name: m['name'] as String,
    priceCents: m['price_cents'] as int,
    stockQty: m['stock_qty'] as int,
    updatedAt: m['updated_at'] as int,
    deleted: m['deleted'] == 1,
  );

  Map<String, Object?> toMap() => {
    'barcode': barcode,
    'name': name,
    'price_cents': priceCents,
    'stock_qty': stockQty,
    'updated_at': updatedAt,
    'deleted': deleted ? 1 : 0,
  };

  Item copyWith({
    String? name,
    int? priceCents,
    int? stockQty,
    int? updatedAt,
    bool? deleted,
  }) => Item(
    barcode: barcode,
    name: name ?? this.name,
    priceCents: priceCents ?? this.priceCents,
    stockQty: stockQty ?? this.stockQty,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );
}
