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

  const noodles = Item(barcode: 'A', name: 'Noodles', priceCents: 1500);
  const gum = Item(barcode: 'B', name: 'Gum', priceCents: 250);

  Future<int> stock(String barcode) async =>
      (await db.query(
            'items',
            where: 'barcode = ?',
            whereArgs: [barcode],
          )).single['stock_qty']
          as int;

  setUp(() async {
    n = 0;
    db = await openAppDb(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repo = SaleRepository(db, () => 5000, newId: () => 'sale-${++n}');
    for (final i in [
      noodles.copyWith(stockQty: 10, updatedAt: 1),
      gum.copyWith(stockQty: 3, updatedAt: 1),
    ]) {
      await db.insert('items', {
        'barcode': i.barcode,
        'name': i.name,
        'price_cents': i.priceCents,
        'stock_qty': i.stockQty,
        'updated_at': i.updatedAt,
      });
    }
  });
  tearDown(() => db.close());

  test('checkout writes the sale, its lines and decrements stock', () async {
    final cart = const Cart().add(noodles).add(noodles).add(gum);
    final id = await repo.checkout(cart, cashCents: 5000);

    expect(id, 'sale-1');
    final sale = (await db.query('sales')).single;
    expect(sale['total_cents'], 3250);
    expect(sale['cash_cents'], 5000);
    expect(sale['created_at'], 5000);

    final lines = await db.query('sale_items', orderBy: 'barcode');
    expect(lines, hasLength(2));
    expect(lines[0]['name_snapshot'], 'Noodles');
    expect(lines[0]['unit_price_cents'], 1500);
    expect(lines[0]['qty'], 2);
    expect(lines[1]['qty'], 1);

    expect(await stock('A'), 8);
    expect(await stock('B'), 2);
  });

  test('cash is optional and stored as null', () async {
    await repo.checkout(const Cart().add(gum));
    expect((await db.query('sales')).single['cash_cents'], isNull);
  });

  test('each sale gets its own id', () async {
    final a = await repo.checkout(const Cart().add(gum));
    final b = await repo.checkout(const Cart().add(gum));
    expect(a, isNot(b));
    expect(await db.query('sales'), hasLength(2));
  });

  test('receipt keeps the old price after the item is re-priced', () async {
    await repo.checkout(const Cart().add(noodles));
    await db.update('items', {'price_cents': 9999}, where: "barcode = 'A'");
    expect((await db.query('sale_items')).single['unit_price_cents'], 1500);
  });

  test('a failure mid-checkout rolls back the sale, lines and stock', () async {
    // The second line breaks the qty > 0 CHECK after the first line and its
    // stock decrement have already run inside the transaction.
    final bad = Cart([
      const CartLine(
        barcode: 'A',
        name: 'Noodles',
        unitPriceCents: 1500,
        qty: 2,
      ),
      const CartLine(barcode: 'B', name: 'Gum', unitPriceCents: 250, qty: 0),
    ]);

    await expectLater(repo.checkout(bad), throwsA(anything));

    expect(await db.query('sales'), isEmpty);
    expect(await db.query('sale_items'), isEmpty);
    expect(await stock('A'), 10);
    expect(await stock('B'), 3);
  });

  test('rejects an empty cart and cash below the total', () async {
    expect(() => repo.checkout(const Cart()), throwsArgumentError);
    expect(
      () => repo.checkout(const Cart().add(noodles), cashCents: 1499),
      throwsArgumentError,
    );
    expect(await db.query('sales'), isEmpty);
  });

  test('stock may go negative instead of blocking the sale', () async {
    var cart = const Cart().add(gum);
    for (var i = 0; i < 4; i++) {
      cart = cart.increment('B');
    }
    await repo.checkout(cart); // qty 5, stock 3
    expect(await stock('B'), -2);
  });

  test('selling does not change items.updated_at', () async {
    await repo.checkout(const Cart().add(gum));
    expect(
      (await db.query('items', where: "barcode = 'B'")).single['updated_at'],
      1,
    );
  });
}
