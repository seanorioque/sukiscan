import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sukiscan/core/db.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  setUp(() async {
    db = await openAppDb(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });
  tearDown(() => db.close());

  test('creates schema v1', () async {
    final names = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
    )).map((r) => r['name']).toSet();
    expect(
      names,
      containsAll(['items', 'sales', 'sale_items', 'idx_sale_items_sale']),
    );
    expect(await db.getVersion(), 1);
  });

  test('rejects non-positive price', () async {
    expect(
      () => db.insert('items', {
        'barcode': '1',
        'name': 'x',
        'price_cents': 0,
        'updated_at': 1,
      }),
      throwsA(anything),
    );
  });

  test('deleting a sale cascades to its lines', () async {
    await db.insert('sales', {'id': 's1', 'created_at': 1, 'total_cents': 100});
    await db.insert('sale_items', {
      'sale_id': 's1',
      'barcode': '1',
      'name_snapshot': 'x',
      'unit_price_cents': 100,
      'qty': 1,
    });
    await db.delete('sales', where: 'id = ?', whereArgs: ['s1']);
    expect(await db.query('sale_items'), isEmpty);
  });
}
