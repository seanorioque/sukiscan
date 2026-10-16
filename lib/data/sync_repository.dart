import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/db.dart';
import '../domain/item.dart';

final syncRepositoryProvider = Provider(
  (ref) => SyncRepository(ref.watch(databaseProvider)),
);

/// What a merge does (or would do), counted by what the user can see.
class MergeSummary {
  const MergeSummary({
    this.created = 0,
    this.updated = 0,
    this.deleted = 0,
    this.unchanged = 0,
  });

  /// Items that become visible here: new barcodes, or deleted ones brought back.
  final int created;

  /// Live items whose data changes.
  final int updated;

  /// Live items that become deleted.
  final int deleted;

  /// Incoming items that change nothing visible: older than ours, identical,
  /// or deletions of items we never had.
  final int unchanged;

  int get changes => created + updated + deleted;
}

class SyncRepository {
  SyncRepository(this._db);

  final Database _db;

  /// What [merge] would do, without writing anything.
  Future<MergeSummary> preview(List<Item> incoming) async =>
      _plan(await _loadAll(_db), incoming).summary;

  /// Merges [incoming] (as decoded from a sync transfer) into the catalog in
  /// ONE transaction: if anything fails, nothing is written.
  ///
  /// Per barcode, last write wins on `updated_at`: an incoming item replaces
  /// ours only if it is strictly newer (a tie keeps ours). Soft deletes are
  /// applied like any other change, and an incoming item keeps its own
  /// `updated_at`: the merge never restamps, so both phones converge.
  Future<MergeSummary> merge(List<Item> incoming) =>
      _db.transaction((txn) async {
        final plan = _plan(await _loadAll(txn), incoming);
        for (final item in plan.writes) {
          await txn.insert(
            'items',
            item.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        return plan.summary;
      });

  Future<Map<String, Item>> _loadAll(DatabaseExecutor db) async => {
    for (final row in await db.query('items'))
      row['barcode'] as String: Item.fromMap(row),
  };

  ({List<Item> writes, MergeSummary summary}) _plan(
    Map<String, Item> existing,
    List<Item> incoming,
  ) {
    final current = {
      ...existing,
    }; // applied as we go, so repeats inside one transfer resolve too
    final writes = <String, Item>{};
    var created = 0, updated = 0, deleted = 0, unchanged = 0;

    for (final item in incoming) {
      final mine = current[item.barcode];
      if (mine != null && item.updatedAt <= mine.updatedAt) {
        unchanged++; // ours is newer or the same: keep ours
        continue;
      }
      current[item.barcode] = item;
      writes[item.barcode] = item;

      if (mine == null || mine.deleted) {
        if (item.deleted) {
          unchanged++; // a deletion of something we don't show anyway
        } else {
          created++;
        }
      } else if (item.deleted) {
        deleted++;
      } else if (_sameData(mine, item)) {
        unchanged++; // only the timestamp moves
      } else {
        updated++;
      }
    }
    return (
      writes: writes.values.toList(),
      summary: MergeSummary(
        created: created,
        updated: updated,
        deleted: deleted,
        unchanged: unchanged,
      ),
    );
  }

  bool _sameData(Item a, Item b) =>
      a.name == b.name &&
      a.priceCents == b.priceCents &&
      a.stockQty == b.stockQty;
}
