import 'dart:convert';
import 'dart:io' show gzip;

import 'item.dart';

/// Items → compact JSON → gzip → base64 (plan §5). Pure Dart, no Flutter.
///
/// Compact keys: b=barcode, n=name, p=price_cents, s=stock_qty,
/// u=updated_at (epoch ms), d=deleted (0/1). Soft-deleted items must be
/// included by the caller so deletions propagate.
String encodeCatalog(List<Item> items) {
  final json = jsonEncode([
    for (final i in items)
      {
        'b': i.barcode,
        'n': i.name,
        'p': i.priceCents,
        's': i.stockQty,
        'u': i.updatedAt,
        'd': i.deleted ? 1 : 0,
      },
  ]);
  return base64Encode(gzip.encode(utf8.encode(json)));
}

/// Reverse of [encodeCatalog]. The data comes from another phone's camera, so
/// everything is checked: any problem throws a [FormatException] and nothing
/// partial is returned.
List<Item> decodeCatalog(String payload) {
  try {
    final json = jsonDecode(utf8.decode(gzip.decode(base64Decode(payload))));
    if (json is! List) throw const FormatException('not a list');
    return [for (final e in json) _item(e)];
  } on FormatException {
    rethrow;
  } catch (_) {
    // gzip errors (e.g. corrupted/truncated data), bad UTF-8, ...
    throw const FormatException('Invalid sync data');
  }
}

Item _item(Object? e) {
  if (e is! Map) throw const FormatException('bad item');
  final b = e['b'], n = e['n'], p = e['p'], s = e['s'], u = e['u'], d = e['d'];
  if (b is! String || b.trim().isEmpty) {
    throw const FormatException('bad barcode');
  }
  if (n is! String || n.trim().isEmpty) {
    throw const FormatException('bad name');
  }
  if (p is! int || p <= 0) throw const FormatException('bad price');
  if (s is! int) throw const FormatException('bad stock'); // may be negative
  if (u is! int || u < 0) throw const FormatException('bad updated_at');
  if (d != 0 && d != 1) throw const FormatException('bad deleted flag');
  return Item(
    barcode: b,
    name: n,
    priceCents: p,
    stockQty: s,
    updatedAt: u,
    deleted: d == 1,
  );
}
