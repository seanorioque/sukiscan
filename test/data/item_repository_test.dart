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

  test('upsert revives a soft-deleted item', () async {
    await repo.upsert(noodles);
    await repo.softDelete(noodles.barcode);
    await repo.upsert(noodles);
    expect((await repo.get(noodles.barcode))!.deleted, isFalse);
  });
}
