import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sukiscan/core/db.dart';
import 'package:sukiscan/data/sale_repository.dart';
import 'package:sukiscan/domain/cart.dart';
import 'package:sukiscan/domain/item.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late SaleRepository repo;
  var n = 0;
  var now = 1000;

  const noodles = Item(barcode: 'A', name: 'Noodles', priceCents: 1500);
  const gum = Item(barcode: 'B', name: 'Gum', priceCents: 250);

  setUp(() async {
    n = 0;
    now = 1000;
    db = await openAppDb(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repo = SaleRepository(db, () => now, newId: () => 'sale-${++n}');
  });
  tearDown(() => db.close());

  test('history is empty before any sale', () async {
    expect(await repo.history(), isEmpty);
  });

  test(
    'history lists sales newest first with totals and item counts',
    () async {
      await repo.checkout(const Cart().add(gum)); // sale-1 at 1000
      now = 2000;
      await repo.checkout(
        const Cart().add(noodles).add(noodles).add(gum),
        cashCents: 5000,
      ); // sale-2 at 2000

      final h = await repo.history();
      expect(h.map((s) => s.id), ['sale-2', 'sale-1']);
      expect(h.first.totalCents, 3250);
      expect(h.first.itemCount, 3); // 2 noodles + 1 gum
      expect(h.first.cashCents, 5000);
      expect(h.last.cashCents, isNull);
    },
  );

  test('lines give back what was sold, as it was then', () async {
    await repo.checkout(const Cart().add(noodles).add(noodles).add(gum));
    final lines = await repo.lines('sale-1');
    expect(lines.map((l) => (l.name, l.qty, l.unitPriceCents)), [
      ('Noodles', 2, 1500),
      ('Gum', 1, 250),
    ]);
    expect(lines.first.totalCents, 3000);
    expect(await repo.lines('nope'), isEmpty);
  });

  test(
    'deleteSales removes the sales and their lines, and only those',
    () async {
      await repo.checkout(const Cart().add(gum));
      await repo.checkout(const Cart().add(noodles));
      await repo.checkout(const Cart().add(gum).add(noodles));

      expect(await repo.deleteSales(['sale-1', 'sale-3']), 2);

      expect((await repo.history()).map((s) => s.id), ['sale-2']);
      final left = await db.query('sale_items');
      expect(left.map((r) => r['sale_id']), ['sale-2']); // lines went too
    },
  );

  test('deleting an unknown sale deletes nothing', () async {
    await repo.checkout(const Cart().add(gum));
    expect(await repo.deleteSales(['nope']), 0);
    expect(await repo.history(), hasLength(1));
  });

  test('deleting history does not touch item stock', () async {
    await db.insert('items', {
      'barcode': 'B',
      'name': 'Gum',
      'price_cents': 250,
      'stock_qty': 5,
      'updated_at': 1,
    });
    await repo.checkout(const Cart().add(gum)); // stock 5 -> 4
    await repo.deleteSales(['sale-1']);
    final stock = (await db.query('items')).single['stock_qty'];
    expect(stock, 4);
  });
}
