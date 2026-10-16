import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/clock.dart';
import '../core/db.dart';
import '../domain/cart.dart';

final saleRepositoryProvider = Provider(
  (ref) =>
      SaleRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

class SaleRepository {
  SaleRepository(this._db, this._now, {String Function()? newId})
    : _newId = newId ?? (() => const Uuid().v4());

  final Database _db;
  final Clock _now;
  final String Function() _newId;

  /// Saves the sale, its lines and the stock decrements in ONE transaction:
  /// if anything fails, nothing is written. Returns the new sale id.
  ///
  /// Line name/price come from the cart (captured when the item was added), so
  /// receipts stay accurate after an item is re-priced.
  /// Stock may go negative: stock is optional and defaults to 0, so a sale
  /// must never be blocked by it. `items.updated_at` is left alone, so selling
  /// doesn't make this phone's catalog look newer to the sync merge.
  Future<String> checkout(Cart cart, {int? cashCents}) async {
    if (cart.isEmpty) throw ArgumentError('Cannot check out an empty cart');
    if (cashCents != null && cashCents < cart.totalCents) {
      throw ArgumentError('Cash is less than the total');
    }
    final id = _newId();
    await _db.transaction((txn) async {
      await txn.insert('sales', {
        'id': id,
        'created_at': _now(),
        'total_cents': cart.totalCents,
        'cash_cents': cashCents,
      });
      for (final line in cart.lines) {
        await txn.insert('sale_items', {
          'sale_id': id,
          'barcode': line.barcode,
          'name_snapshot': line.name,
          'unit_price_cents': line.unitPriceCents,
          'qty': line.qty,
        });
        await txn.rawUpdate(
          'UPDATE items SET stock_qty = stock_qty - ? WHERE barcode = ?',
          [line.qty, line.barcode],
        );
      }
    });
    return id;
  }
}
