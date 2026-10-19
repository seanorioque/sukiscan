import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindascan/core/clock.dart';
import 'package:tindascan/data/csv_files.dart';
import 'package:tindascan/data/item_repository.dart';
import 'package:tindascan/domain/item.dart';
import 'package:tindascan/features/encode/item_list_screen.dart';
import 'package:tindascan/shared/app_feedback.dart';

import '../helpers/fake_csv_files.dart';
import '../helpers/fake_item_repo.dart';
import '../helpers/recording_feedback.dart';

const header = 'barcode,item name,price,stock quantity';

void main() {
  late FakeItemRepo repo;
  late FakeCsvFiles csv;
  final feedback = RecordingFeedback();
  setUp(feedback.events.clear);

  const noodles = Item(
    barcode: '4800016644290',
    name: 'Pancit Canton',
    priceCents: 1500,
    stockQty: 24,
  );
  const gum = Item(barcode: '111', name: 'Gum', priceCents: 250);

  Future<void> pump(WidgetTester tester, {List<Item> items = const []}) async {
    repo = FakeItemRepo();
    for (final i in items) {
      repo.store[i.barcode] = i;
    }
    csv = FakeCsvFiles();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemRepositoryProvider.overrideWithValue(repo),
          csvFilesProvider.overrideWithValue(csv),
          feedbackProvider.overrideWithValue(feedback),
          clockProvider.overrideWithValue(
            () => DateTime(2026, 10, 16, 12).millisecondsSinceEpoch,
          ),
        ],
        child: const MaterialApp(home: ItemListScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickFromMenu(WidgetTester tester, String entry) async {
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(entry));
    await tester.pumpAndSettle();
  }

  Future<void> tapImport(WidgetTester tester) =>
      pickFromMenu(tester, 'Import from CSV');

  Future<void> tapExport(WidgetTester tester) =>
      pickFromMenu(tester, 'Export to CSV');

  testWidgets('the menu has Sync, Import and Export', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Sync with another phone'), findsOneWidget);
    expect(find.text('Import from CSV'), findsOneWidget);
    expect(find.text('Export to CSV'), findsOneWidget);
  });

  group('export', () {
    testWidgets('saves every item as CSV, named with today\'s date', (
      tester,
    ) async {
      await pump(tester, items: [noodles, gum]);
      await tapExport(tester);

      expect(csv.saved, hasLength(1));
      expect(csv.saved.single.name, 'tindascan-items-2026-10-16.csv');
      // A UTF-8 byte order mark first, so Excel reads names like "Piña" right.
      expect(csv.saved.single.bytes.take(3), [0xEF, 0xBB, 0xBF]);
      expect(
        csv.saved.single.text,
        '$header\r\n'
        '111,Gum,2.50,0\r\n' // A-Z by name
        '4800016644290,Pancit Canton,15.00,24\r\n',
      );
      expect(find.text('Exported 2 items'), findsOneWidget);
      expect(feedback.events, ['success']);
    });

    testWidgets('one item reads "1 item"', (tester) async {
      await pump(tester, items: [gum]);
      await tapExport(tester);
      expect(find.text('Exported 1 item'), findsOneWidget);
    });

    testWidgets('cancelling the save dialog says nothing', (tester) async {
      await pump(tester, items: [gum]);
      csv.saveAccepted = false;
      await tapExport(tester);

      expect(csv.saved, hasLength(1)); // it was offered...
      expect(find.textContaining('Exported'), findsNothing); // ...but not saved
      expect(feedback.events, isEmpty);
    });

    testWidgets('nothing to export is explained, not saved', (tester) async {
      await pump(tester);
      await tapExport(tester);

      expect(find.text('There are no items to export yet.'), findsOneWidget);
      expect(csv.saved, isEmpty);
    });

    testWidgets('a save failure is reported', (tester) async {
      await pump(tester, items: [gum]);
      csv.failSave = true;
      await tapExport(tester);

      expect(
        find.text('Could not export your items. Please try again.'),
        findsOneWidget,
      );
      expect(feedback.events, ['error']);
    });
  });

  group('import', () {
    testWidgets('a good file adds and updates items', (tester) async {
      await pump(tester, items: [noodles]);
      csv.pickText(
        '$header\n'
        '111,Gum,2.50,5\n'
        '222,Soda,"1,200.00",\n'
        '4800016644290,Pancit Canton Spicy,16.50,\n', // existing: blank stock
      );
      await tapImport(tester);

      expect(find.text('Imported 3 items: 2 new, 1 updated'), findsOneWidget);
      expect(repo.store['111']!.stockQty, 5);
      expect(repo.store['222']!.priceCents, 120000);
      expect(repo.store['222']!.stockQty, 0); // blank on a new item
      final updated = repo.store['4800016644290']!;
      expect(updated.name, 'Pancit Canton Spicy');
      expect(updated.priceCents, 1650);
      expect(updated.stockQty, 24); // blank keeps the current stock
      expect(feedback.events, ['success']);

      // The list shows the new items straight away.
      expect(find.text('Items (3)'), findsOneWidget);
      expect(find.text('Soda'), findsOneWidget);
    });

    testWidgets('a blank stock quantity is the only blank allowed', (
      tester,
    ) async {
      await pump(tester);
      csv.pickText('$header\n111,Gum,2.50,\n');
      await tapImport(tester);

      expect(find.text('Import failed'), findsNothing);
      expect(repo.store.keys, ['111']);
    });

    testWidgets('a missing item name fails the import and says why', (
      tester,
    ) async {
      await pump(tester);
      csv.pickText('$header\n111,Gum,2.50,5\n222,,3.00,1\n');
      await tapImport(tester);

      expect(find.text('Import failed'), findsOneWidget);
      expect(find.textContaining('Nothing was imported'), findsOneWidget);
      expect(find.text('• Row 3: item name is empty.'), findsOneWidget);
      expect(repo.store, isEmpty); // the good row 2 was not imported either
      expect(repo.imported, isEmpty);
      expect(feedback.events, ['error']);
    });

    testWidgets('a missing barcode and a missing price are reported too', (
      tester,
    ) async {
      await pump(tester);
      csv.pickText('$header\n,Gum,2.50,5\n222,Soda,,1\n');
      await tapImport(tester);

      expect(find.text('• Row 2: barcode is empty.'), findsOneWidget);
      expect(find.text('• Row 3: price is empty.'), findsOneWidget);
      expect(repo.store, isEmpty);
    });

    testWidgets('an invalid price names the value', (tester) async {
      await pump(tester);
      csv.pickText('$header\n111,Gum,abc,5\n');
      await tapImport(tester);

      expect(
        find.text(
          '• Row 2: price "abc" is not a valid amount (use a number like 12.50).',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the dialog closes with OK and the list is unchanged', (
      tester,
    ) async {
      await pump(tester, items: [noodles]);
      csv.pickText('$header\n111,,2.50,\n');
      await tapImport(tester);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Import failed'), findsNothing);
      expect(find.text('Items (1)'), findsOneWidget);
      expect(repo.store.keys, ['4800016644290']);
    });

    testWidgets('a long list of problems is cut off with a count', (
      tester,
    ) async {
      await pump(tester);
      final rows = [for (var i = 0; i < 12; i++) '$i,,1.00,'];
      csv.pickText('$header\n${rows.join('\n')}\n');
      await tapImport(tester);

      expect(find.text('• Row 2: item name is empty.'), findsOneWidget);
      expect(find.text('• Row 9: item name is empty.'), findsOneWidget);
      expect(find.text('• Row 10: item name is empty.'), findsNothing);
      expect(find.text('…and 4 more.'), findsOneWidget);
    });

    testWidgets('the wrong kind of file is explained', (tester) async {
      await pump(tester);
      csv.pickText('name,price\nGum,2.5\n');
      await tapImport(tester);

      expect(
        find.textContaining('Missing: barcode, item name'),
        findsOneWidget,
      );
    });

    testWidgets('cancelling the file picker does nothing', (tester) async {
      await pump(tester);
      csv.toPick = null;
      await tapImport(tester);

      expect(find.text('Import failed'), findsNothing);
      expect(find.textContaining('Imported'), findsNothing);
      expect(repo.imported, isEmpty);
      expect(feedback.events, isEmpty);
    });

    testWidgets('a file that cannot be opened is reported', (tester) async {
      await pump(tester);
      csv.failPick = true;
      await tapImport(tester);

      expect(
        find.text('Could not open that file. Please try again.'),
        findsOneWidget,
      );
      expect(feedback.events, ['error']);
    });

    testWidgets('a database failure leaves everything unchanged', (
      tester,
    ) async {
      await pump(tester);
      repo.failWrites = true;
      csv.pickText('$header\n111,Gum,2.50,5\n');
      await tapImport(tester);

      expect(
        find.text('Could not save the imported items. Nothing was changed.'),
        findsOneWidget,
      );
      expect(repo.store, isEmpty);
      expect(feedback.events, ['error']);
    });
  });
}
