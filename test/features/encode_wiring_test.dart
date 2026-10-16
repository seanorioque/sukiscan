import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sukiscan/core/clock.dart';
import 'package:sukiscan/core/db.dart';
import 'package:sukiscan/data/item_repository.dart';
import 'package:sukiscan/features/encode/encode_screen.dart';
import 'package:sukiscan/shared/app_feedback.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  sqfliteFfiInit();

  // Real providers + real (in-memory) SQLite; no fake repository.
  testWidgets('Encode screen saves to SQLite through the real providers', (
    tester,
  ) async {
    late Database db;
    await tester.runAsync(() async {
      db = await openAppDb(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
    });
    addTearDown(() => tester.runAsync(db.close));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => 42),
          // Real feedback, but no audio plugin in tests.
          feedbackProvider.overrideWithValue(AppFeedback(beep: (_) async {})),
        ],
        child: const MaterialApp(home: EncodeScreen()),
      ),
    );
    final repo = ProviderScope.containerOf(
      tester.element(find.byType(EncodeScreen)),
    ).read(itemRepositoryProvider);

    // Create.
    await tester.enterText(field('Barcode'), '123');
    await tester.enterText(field('Item name'), 'Gum');
    await tester.enterText(field('Price'), '2.5');
    await tester.enterText(field('Stock quantity (optional)'), '7');
    await tester.tap(find.text('Save'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(() => repo.get('123'));
    expect(saved!.name, 'Gum');
    expect(saved.priceCents, 250);
    expect(saved.stockQty, 7);
    expect(saved.updatedAt, 42);
  });
}
