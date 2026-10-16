import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/clock.dart';
import '../core/db.dart';
import '../domain/item.dart';
import '../domain/items_csv.dart';

final itemRepositoryProvider = Provider(
  (ref) =>
      ItemRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// How many items are saved (not deleted). Drives the "no items yet" hints.
/// Invalidate after anything that adds or removes items (Encode, sync import).
final itemCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(itemRepositoryProvider).countLive(),
);

/// All saved (not deleted) items, A–Z by name, for the items list.
final itemListProvider = FutureProvider.autoDispose<List<Item>>(
  (ref) => ref.watch(itemRepositoryProvider).allLive(),
);

/// Call after anything adds, changes or removes items, so the items list and
/// the "no items yet" hints refresh.
void refreshItems(WidgetRef ref) {
  ref.invalidate(itemCountProvider);
  ref.invalidate(itemListProvider);
}

class ItemRepository {
  ItemRepository(this._db, this._now);

  final Database _db;
  final Clock _now;

  /// Soft-deleted items count as absent.
  Future<Item?> get(String barcode) async {
    final rows = await _db.query(
      'items',
      where: 'barcode = ? AND deleted = 0',
      whereArgs: [barcode],
    );
    return rows.isEmpty ? null : Item.fromMap(rows.first);
  }

  /// Insert or update by barcode, stamping `updated_at` and clearing `deleted`.
  Future<Item> upsert(Item item) async {
    final saved = item.copyWith(updatedAt: _now(), deleted: false);
    await _db.insert(
      'items',
      saved.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return saved;
  }

  /// Saves every row of a CSV import in ONE transaction: if anything fails,
  /// nothing is written. A barcode that already exists is updated (and a
  /// deleted one comes back); a blank stock keeps the existing stock, or is 0
  /// for a new item. Rows are stamped with the current time so a later sync
  /// sends them on.
  Future<({int created, int updated})> importItems(List<CsvItem> rows) =>
      _db.transaction((txn) async {
        var created = 0, updated = 0;
        final now = _now();
        for (final row in rows) {
          final found = await txn.query(
            'items',
            where: 'barcode = ?',
            whereArgs: [row.barcode],
          );
          final live = found.isNotEmpty && found.first['deleted'] == 0;
          await txn.insert(
            'items',
            Item(
              barcode: row.barcode,
              name: row.name,
              priceCents: row.priceCents,
              stockQty:
                  row.stockQty ?? (live ? found.first['stock_qty'] as int : 0),
              updatedAt: now,
            ).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          live ? updated++ : created++;
        }
        return (created: created, updated: updated);
      });

  Future<List<Item>> allLive() async => [
    for (final row in await _db.query(
      'items',
      where: 'deleted = 0',
      orderBy: 'name COLLATE NOCASE, barcode',
    ))
      Item.fromMap(row),
  ];

  Future<int> countLive() async =>
      Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM items WHERE deleted = 0'),
      ) ??
      0;

  /// Marks the item deleted (kept in the table so deletions propagate in sync).
  Future<void> softDelete(String barcode) => _db.update(
    'items',
    {'deleted': 1, 'updated_at': _now()},
    where: 'barcode = ?',
    whereArgs: [barcode],
  );
}
