import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sukiscan/core/db.dart';
import 'package:sukiscan/data/item_repository.dart';
import 'package:sukiscan/domain/item.dart';
import 'package:sukiscan/domain/items_csv.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late ItemRepository repo;
  var now = 1000;

  setUp(() async {
    now = 1000;
    db = await openAppDb(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repo = ItemRepository(db, () => now);
  });
  tearDown(() => db.close());

  const noodles = Item(
    barcode: '4800016644290',
    name: 'Pancit Canton',
    priceCents: 1500,
    stockQty: 24,
  );

  test('get returns null when missing', () async {
    expect(await repo.get('nope'), isNull);
  });

  test('upsert inserts, stamping updated_at', () async {
    await repo.upsert(noodles);
    final got = (await repo.get(noodles.barcode))!;
    expect(got.name, 'Pancit Canton');
    expect(got.priceCents, 1500);
    expect(got.stockQty, 24);
    expect(got.updatedAt, 1000);
  });

  test('upsert updates existing barcode without duplicating', () async {
    await repo.upsert(noodles);
    now = 2000;
    await repo.upsert(noodles.copyWith(priceCents: 1600));
    expect(await db.query('items'), hasLength(1));
    final got = (await repo.get(noodles.barcode))!;
    expect(got.priceCents, 1600);
    expect(got.updatedAt, 2000);
  });

  test('softDelete hides the item but keeps the row', () async {
    await repo.upsert(noodles);
    now = 3000;
    await repo.softDelete(noodles.barcode);
    expect(await repo.get(noodles.barcode), isNull);
    final raw = (await db.query('items')).single; // the row is still there
    expect(raw['deleted'], 1);
    expect(raw['updated_at'], 3000);
  });

  test('countLive counts saved items and ignores soft-deleted ones', () async {
    expect(await repo.countLive(), 0);
    await repo.upsert(noodles);
    await repo.upsert(const Item(barcode: 'B', name: 'Gum', priceCents: 250));
    expect(await repo.countLive(), 2);
    await repo.softDelete(noodles.barcode);
    expect(await repo.countLive(), 1);
  });

  test(
    'allLive lists saved items A-Z by name and skips deleted ones',
    () async {
      await repo.upsert(
        const Item(barcode: '3', name: 'zebra', priceCents: 100),
      );
      await repo.upsert(
        const Item(barcode: '1', name: 'Apple', priceCents: 100),
      );
      await repo.upsert(
        const Item(barcode: '2', name: 'banana', priceCents: 100),
      );
      await repo.upsert(
        const Item(barcode: '4', name: 'gone', priceCents: 100),
      );
      await repo.softDelete('4');

      final all = await repo.allLive();
      expect(all.map((i) => i.name), [
        'Apple',
        'banana',
        'zebra',
      ]); // case-insensitive
      expect(all.first.priceCents, 100);
    },
  );

  group('importItems', () {
    Future<Map<String, Object?>> row(String barcode) async => (await db.query(
      'items',
      where: 'barcode = ?',
      whereArgs: [barcode],
    )).single;

    test('adds new items, stamped with the current time', () async {
      now = 7000;
      final r = await repo.importItems(const [
        CsvItem(barcode: 'A', name: 'Noodles', priceCents: 1500, stockQty: 24),
        CsvItem(barcode: 'B', name: 'Gum', priceCents: 250),
      ]);

      expect((r.created, r.updated), (2, 0));
      expect((await row('A'))['stock_qty'], 24);
      expect((await row('B'))['stock_qty'], 0); // blank stock on a new item
      expect((await row('A'))['updated_at'], 7000);
      expect((await row('A'))['deleted'], 0);
    });

    test(
      'updates an existing item; blank stock keeps the current stock',
      () async {
        await repo.upsert(noodles); // stock 24
        now = 8000;
        final r = await repo.importItems(const [
          CsvItem(barcode: '4800016644290', name: 'Renamed', priceCents: 1700),
        ]);

        expect((r.created, r.updated), (0, 1));
        final got = (await repo.get(noodles.barcode))!;
        expect(got.name, 'Renamed');
        expect(got.priceCents, 1700);
        expect(got.stockQty, 24); // untouched
        expect(got.updatedAt, 8000);
      },
    );

    test('a given stock replaces the current stock, even 0', () async {
      await repo.upsert(noodles);
      await repo.importItems(const [
        CsvItem(
          barcode: '4800016644290',
          name: 'Pancit Canton',
          priceCents: 1500,
          stockQty: 0,
        ),
      ]);
      expect((await repo.get(noodles.barcode))!.stockQty, 0);
    });

    test('brings back a deleted item as new, ignoring its old stock', () async {
      await repo.upsert(noodles);
      await repo.softDelete(noodles.barcode);

      final r = await repo.importItems(const [
        CsvItem(barcode: '4800016644290', name: 'Back', priceCents: 900),
      ]);

      expect((r.created, r.updated), (1, 0));
      final got = (await repo.get(noodles.barcode))!;
      expect(got.name, 'Back');
      expect(got.stockQty, 0);
      expect(got.deleted, isFalse);
    });

    test('all or nothing: one failing row undoes the rest', () async {
      await repo.upsert(noodles);
      await expectLater(
        repo.importItems(const [
          CsvItem(barcode: 'NEW', name: 'Fine', priceCents: 100),
          CsvItem(barcode: '4800016644290', name: 'Changed', priceCents: 100),
          // The table refuses a price of 0: the last line of defence.
          CsvItem(barcode: 'BAD', name: 'Bad', priceCents: 0),
        ]),
        throwsA(anything),
      );

      expect(await db.query('items', where: "barcode = 'NEW'"), isEmpty);
      expect(await db.query('items', where: "barcode = 'BAD'"), isEmpty);
      expect((await repo.get(noodles.barcode))!.name, 'Pancit Canton');
    });
  });

  test('upsert revives a soft-deleted item', () async {
    await repo.upsert(noodles);
    await repo.softDelete(noodles.barcode);
    await repo.upsert(noodles);
    expect((await repo.get(noodles.barcode))!.deleted, isFalse);
  });
}
