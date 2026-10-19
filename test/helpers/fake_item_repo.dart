import 'package:tindascan/data/item_repository.dart';
import 'package:tindascan/domain/item.dart';
import 'package:tindascan/domain/items_csv.dart';

/// In-memory ItemRepository for widget tests (no SQLite).
class FakeItemRepo implements ItemRepository {
  final store = <String, Item>{};
  final deleted = <String>[];
  var lookups = 0;
  var upserts = 0;

  /// Make reads (get) or writes (upsert, softDelete) throw, like a failing database.
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<Item?> get(String barcode) async {
    lookups++;
    if (failReads) throw StateError('db down');
    return store[barcode];
  }

  @override
  Future<int> countLive() async => store.length;

  /// Every list passed to importItems.
  final imported = <List<CsvItem>>[];

  @override
  Future<({int created, int updated})> importItems(List<CsvItem> rows) async {
    if (failWrites) throw StateError('db down');
    imported.add(rows);
    var created = 0, updated = 0;
    for (final r in rows) {
      final old = store[r.barcode];
      store[r.barcode] = Item(
        barcode: r.barcode,
        name: r.name,
        priceCents: r.priceCents,
        stockQty: r.stockQty ?? old?.stockQty ?? 0,
      );
      old == null ? created++ : updated++;
    }
    return (created: created, updated: updated);
  }

  @override
  Future<List<Item>> allLive() async {
    if (failReads) throw StateError('db down');
    return [...store.values]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<Item> upsert(Item item) async {
    if (failWrites) throw StateError('db down');
    upserts++;
    return store[item.barcode] = item;
  }

  @override
  Future<void> softDelete(String barcode) async {
    if (failWrites) throw StateError('db down');
    deleted.add(barcode);
    store.remove(barcode);
  }
}
