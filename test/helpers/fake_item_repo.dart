import 'package:sukiscan/data/item_repository.dart';
import 'package:sukiscan/domain/item.dart';

/// In-memory ItemRepository for widget tests (no SQLite).
class FakeItemRepo implements ItemRepository {
  final store = <String, Item>{};
  final deleted = <String>[];
  var lookups = 0;
  var upserts = 0;

  @override
  Future<Item?> get(String barcode, {bool includeDeleted = false}) async {
    lookups++;
    return store[barcode];
  }

  @override
  Future<int> countLive() async => store.length;

  @override
  Future<Item> upsert(Item item) async {
    upserts++;
    return store[item.barcode] = item;
  }

  @override
  Future<void> softDelete(String barcode) async {
    deleted.add(barcode);
    store.remove(barcode);
  }
}
