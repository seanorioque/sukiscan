import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/clock.dart';
import '../core/db.dart';
import '../domain/item.dart';

final itemRepositoryProvider = Provider(
  (ref) => ItemRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

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
    await _db.insert('items', saved.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return saved;
  }

  /// Marks the item deleted (kept in the table so deletions propagate in sync).
  Future<void> softDelete(String barcode) => _db.update(
        'items',
        {'deleted': 1, 'updated_at': _now()},
        where: 'barcode = ?',
        whereArgs: [barcode],
      );
}
