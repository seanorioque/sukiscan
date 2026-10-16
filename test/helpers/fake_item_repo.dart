import 'package:sukiscan/data/item_repository.dart';
import 'package:sukiscan/domain/item.dart';

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
  Future<Item?> get(String barcode, {bool includeDeleted = false}) async {
    lookups++;
    if (failReads) throw StateError('db down');
    return store[barcode];
  }

  @override
  Future<int> countLive() async => store.length;

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
