import 'package:sukiscan/domain/item.dart';

/// [n] realistic-looking items with distinct barcodes, for sync tests.
List<Item> catalog(int n) => [
  for (var i = 0; i < n; i++)
    Item(
      barcode: '4800${(i * 7919 % 100000000).toString().padLeft(9, '0')}',
      name: 'Item ${i * 31 % 977} brand ${i % 53}',
      priceCents: 1000 + (i * 37 % 9000),
      stockQty: i % 30,
      updatedAt: 1760600000000 + i * 1234567,
    ),
];
