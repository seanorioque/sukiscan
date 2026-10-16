import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/clock.dart';
import '../core/db.dart';
import '../domain/item.dart';

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

  /// Soft-deleted items are treated as absent unless [includeDeleted] is set.
  Future<Item?> get(String barcode, {bool includeDeleted = false}) async {
    final rows = await _db.query(
      'items',
      where: includeDeleted ? 'barcode = ?' : 'barcode = ? AND deleted = 0',
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
