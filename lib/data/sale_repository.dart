import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/clock.dart';
import '../core/db.dart';
import '../domain/cart.dart';
import '../domain/sale.dart';

final saleRepositoryProvider = Provider(
  (ref) =>
      SaleRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

class SaleRepository {
  SaleRepository(this._db, this._now, {String Function()? newId})
    : _newId =
          newId ?? (() => DateTime.now().microsecondsSinceEpoch.toString());

  final Database _db;
  final Clock _now;
  final String Function() _newId;

  /// Saves the sale, its lines and the stock decrements in ONE transaction:
  /// if anything fails, nothing is written. Returns the new sale id.
  ///
  /// Line name/price come from the cart (captured when the item was added), so
  /// receipts stay accurate after an item is re-priced.
  /// Stock never goes below 0. It is optional and defaults to 0, so a sale
  /// is never blocked by it; it just stops at 0. `items.updated_at` is left alone, so selling
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
          'UPDATE items SET stock_qty = MAX(stock_qty - ?, 0) WHERE barcode = ?',
          [line.qty, line.barcode],
        );
      }
    });
    return id;
  }

  /// Every sale, newest first.
  Future<List<SaleSummary>> history() async {
    final rows = await _db.rawQuery('''
SELECT s.id, s.created_at, s.total_cents, s.cash_cents,
       COALESCE(SUM(i.qty), 0) AS item_count
FROM sales s LEFT JOIN sale_items i ON i.sale_id = s.id
GROUP BY s.id
ORDER BY s.created_at DESC, s.rowid DESC''');
    return [
      for (final r in rows)
        SaleSummary(
          id: r['id'] as String,
          createdAt: r['created_at'] as int,
          totalCents: r['total_cents'] as int,
          cashCents: r['cash_cents'] as int?,
          itemCount: r['item_count'] as int,
        ),
    ];
  }

  Future<List<SaleLine>> lines(String saleId) async {
    final rows = await _db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'rowid',
    );
    return [
      for (final r in rows)
        SaleLine(
          barcode: r['barcode'] as String,
          name: r['name_snapshot'] as String,
          unitPriceCents: r['unit_price_cents'] as int,
          qty: r['qty'] as int,
        ),
    ];
  }

  /// Deletes these sales and their lines in ONE transaction. Stock is not
  /// given back: this only tidies the history. Returns how many were deleted.
  Future<int> deleteSales(Iterable<String> ids) => _db.transaction((txn) async {
    var n = 0;
    for (final id in ids) {
      n += await txn.delete('sales', where: 'id = ?', whereArgs: [id]);
    }
    return n;
  });
}

final saleHistoryProvider = FutureProvider.autoDispose<List<SaleSummary>>(
  (ref) => ref.watch(saleRepositoryProvider).history(),
);

final saleLinesProvider = FutureProvider.autoDispose
    .family<List<SaleLine>, String>(
      (ref, id) => ref.watch(saleRepositoryProvider).lines(id),
    );
