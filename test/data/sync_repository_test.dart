import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sukiscan/core/db.dart';
import 'package:sukiscan/data/sync_repository.dart';
import 'package:sukiscan/domain/item.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late SyncRepository repo;

  Item item(
    String barcode, {
    String name = 'Thing',
    int price = 100,
    int stock = 0,
    required int at,
    bool deleted = false,
  }) => Item(
    barcode: barcode,
    name: name,
    priceCents: price,
    stockQty: stock,
    updatedAt: at,
    deleted: deleted,
  );

  Future<void> seed(Item i) => db.insert(
    'items',
    i.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<Item?> row(String barcode) async {
    final rows = await db.query(
      'items',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    return rows.isEmpty ? null : Item.fromMap(rows.single);
  }

  setUp(() async {
    db = await openAppDb(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repo = SyncRepository(db);
  });
  tearDown(() => db.close());

  test('new items are inserted exactly as received', () async {
    final s = await repo.merge([
      item('A', name: 'Noodles', price: 1500, stock: 7, at: 111),
    ]);

    expect((s.created, s.updated, s.deleted, s.unchanged), (1, 0, 0, 0));
    final got = (await row('A'))!;
    expect(got.name, 'Noodles');
    expect(got.priceCents, 1500);
    expect(got.stockQty, 7);
    expect(got.updatedAt, 111); // not restamped
    expect(got.deleted, isFalse);
  });

  test('newer incoming wins and keeps its own updated_at', () async {
    await seed(item('A', name: 'Old', price: 100, at: 100));
    final s = await repo.merge([item('A', name: 'New', price: 200, at: 500)]);

    expect(s.updated, 1);
    final got = (await row('A'))!;
    expect(got.name, 'New');
    expect(got.priceCents, 200);
    expect(got.updatedAt, 500);
  });

  test('older incoming is ignored', () async {
    await seed(item('A', name: 'Mine', at: 500));
    final s = await repo.merge([item('A', name: 'Theirs', at: 100)]);

    expect((s.updated, s.unchanged), (0, 1));
    expect((await row('A'))!.name, 'Mine');
    expect((await row('A'))!.updatedAt, 500);
  });

  test('a tie keeps ours', () async {
    await seed(item('A', name: 'Mine', at: 500));
    await repo.merge([item('A', name: 'Theirs', at: 500)]);
    expect((await row('A'))!.name, 'Mine');
  });

  test('a newer incoming delete soft-deletes our live item', () async {
    await seed(item('A', at: 100));
    final s = await repo.merge([item('A', at: 300, deleted: true)]);

    expect(s.deleted, 1);
    final got = (await row('A'))!;
    expect(got.deleted, isTrue); // row kept as a tombstone
    expect(got.updatedAt, 300);
  });

  test('an older incoming delete does not delete our newer item', () async {
    await seed(item('A', name: 'Edited later', at: 900));
    await repo.merge([item('A', at: 300, deleted: true)]);
    expect((await row('A'))!.deleted, isFalse);
  });

  test(
    'a newer live item revives a deleted one; an older one does not',
    () async {
      await seed(item('A', at: 300, deleted: true));

      var s = await repo.merge([item('A', name: 'Old edit', at: 200)]);
      expect(s.created, 0);
      expect((await row('A'))!.deleted, isTrue);

      s = await repo.merge([item('A', name: 'Back', at: 400)]);
      expect(s.created, 1);
      expect((await row('A'))!.deleted, isFalse);
      expect((await row('A'))!.name, 'Back');
    },
  );

  test(
    'a delete for an item we never had is kept as a tombstone, not counted',
    () async {
      final s = await repo.merge([item('Z', at: 300, deleted: true)]);

      expect((s.created, s.deleted, s.unchanged), (0, 0, 1));
      expect((await row('Z'))!.deleted, isTrue);
      // ...so an older live copy arriving later cannot resurrect it.
      await repo.merge([item('Z', at: 100)]);
      expect((await row('Z'))!.deleted, isTrue);
    },
  );

  test('identical data with a newer timestamp counts as unchanged', () async {
    await seed(item('A', name: 'Same', price: 100, stock: 3, at: 100));
    final s = await repo.merge([
      item('A', name: 'Same', price: 100, stock: 3, at: 200),
    ]);

    expect((s.updated, s.unchanged), (0, 1));
    expect((await row('A'))!.updatedAt, 200);
  });

  test('items missing from the transfer are left alone', () async {
    await seed(item('KEEP', at: 100));
    await repo.merge([item('A', at: 100)]);
    expect(await row('KEEP'), isNotNull);
    expect((await row('KEEP'))!.deleted, isFalse);
  });

  test('repeated barcodes in one transfer resolve by updated_at', () async {
    await repo.merge([
      item('A', name: 'newest', at: 300),
      item('A', name: 'older', at: 100),
      item('A', name: 'middle', at: 200),
    ]);
    expect((await row('A'))!.name, 'newest');
  });

  test('a mixed transfer is summarised correctly', () async {
    await seed(item('UPD', name: 'a', at: 100));
    await seed(item('DEL', at: 100));
    await seed(item('OLD', name: 'mine', at: 900));
    await seed(item('GONE', at: 100, deleted: true));

    final s = await repo.merge([
      item('NEW1', at: 100),
      item('NEW2', at: 100),
      item('UPD', name: 'b', at: 200),
      item('DEL', at: 200, deleted: true),
      item('OLD', name: 'theirs', at: 100),
      item('GONE', at: 50, deleted: true),
    ]);

    expect((s.created, s.updated, s.deleted, s.unchanged), (2, 1, 1, 2));
    expect(s.changes, 4);
  });

  test('preview reports the same counts as merge and writes nothing', () async {
    await seed(item('UPD', name: 'a', at: 100));
    final incoming = [item('NEW', at: 100), item('UPD', name: 'b', at: 200)];

    final p = await repo.preview(incoming);
    expect(await row('NEW'), isNull);
    expect((await row('UPD'))!.name, 'a');

    final m = await repo.merge(incoming);
    expect(
      (p.created, p.updated, p.deleted, p.unchanged),
      (m.created, m.updated, m.deleted, m.unchanged),
    );
  });

  test('a failure part-way rolls the whole merge back', () async {
    await seed(item('A', name: 'Mine', at: 100));
    final incoming = [
      item('NEW', at: 100),
      item('A', name: 'Theirs', at: 500),
      // price 0 breaks the table's CHECK: the DB is the last line of defence.
      item('BAD', price: 0, at: 100),
    ];

    await expectLater(repo.merge(incoming), throwsA(anything));

    expect(await row('NEW'), isNull);
    expect((await row('A'))!.name, 'Mine');
    expect((await row('A'))!.updatedAt, 100);
    expect(await row('BAD'), isNull);
  });

  test('merging an empty transfer is a no-op', () async {
    final s = await repo.merge([]);
    expect(s.changes + s.unchanged, 0);
  });
}
