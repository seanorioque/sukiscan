import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

const dbVersion = 1;

/// Overridden in main() with the opened database (and in tests).
final databaseProvider = Provider<Database>(
  (_) => throw UnimplementedError('override databaseProvider'),
);

const _schemaV1 = [
  '''
CREATE TABLE items (
  barcode     TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  price_cents INTEGER NOT NULL CHECK (price_cents > 0),
  stock_qty   INTEGER NOT NULL DEFAULT 0,
  updated_at  INTEGER NOT NULL,
  deleted     INTEGER NOT NULL DEFAULT 0
)''',
  '''
CREATE TABLE sales (
  id          TEXT PRIMARY KEY,
  created_at  INTEGER NOT NULL,
  total_cents INTEGER NOT NULL,
  cash_cents  INTEGER
)''',
  '''
CREATE TABLE sale_items (
  sale_id          TEXT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  barcode          TEXT NOT NULL,
  name_snapshot    TEXT NOT NULL,
  unit_price_cents INTEGER NOT NULL,
  qty              INTEGER NOT NULL CHECK (qty > 0)
)''',
  'CREATE INDEX idx_sale_items_sale ON sale_items(sale_id)',
];

/// Opens the app database. Pass [factory] / [path] in tests
/// (e.g. `databaseFactoryFfi` + `inMemoryDatabasePath`).
Future<Database> openAppDb({DatabaseFactory? factory, String? path}) async {
  final f = factory ?? databaseFactory;
  return f.openDatabase(
    path ?? p.join(await f.getDatabasesPath(), 'sukiscan.db'),
    options: OpenDatabaseOptions(
      version: dbVersion,
      // SQLite ignores ON DELETE CASCADE unless this is on.
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        for (final sql in _schemaV1) {
          await db.execute(sql);
        }
      },
      // Bumping dbVersion needs an `onUpgrade: (db, from, to)` with `if (from < 2)`
      // steps; v1 is the first schema, so there is nothing to upgrade yet.
    ),
  );
}
