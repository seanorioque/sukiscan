import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sukiscan/core/db.dart';
import 'package:sukiscan/data/item_repository.dart';
import 'package:sukiscan/domain/item.dart';

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
    final raw = (await repo.get(noodles.barcode, includeDeleted: true))!;
    expect(raw.deleted, isTrue);
    expect(raw.updatedAt, 3000);
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

  test('upsert revives a soft-deleted item', () async {
    await repo.upsert(noodles);
    await repo.softDelete(noodles.barcode);
    await repo.upsert(noodles);
    expect((await repo.get(noodles.barcode))!.deleted, isFalse);
  });
}
