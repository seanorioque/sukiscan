import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindascan/data/item_repository.dart';
import 'package:tindascan/domain/item.dart';
import 'package:tindascan/features/encode/item_list_screen.dart';
import 'package:tindascan/shared/app_feedback.dart';

import '../helpers/fake_item_repo.dart';
import '../helpers/recording_feedback.dart';

void main() {
  late FakeItemRepo repo;

  const noodles = Item(
    barcode: '4800016644290',
    name: 'Pancit Canton',
    priceCents: 1500,
    stockQty: 24,
  );
  const gum = Item(barcode: '111', name: 'bubble gum', priceCents: 250);
  const coffee = Item(
    barcode: '999222',
    name: 'Coffee 3-in-1',
    priceCents: 1250,
    stockQty: 7,
  );

  Future<void> pump(WidgetTester tester, {List<Item>? items}) async {
    repo = FakeItemRepo();
    for (final i in items ?? [noodles, gum, coffee]) {
      repo.store[i.barcode] = i;
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemRepositoryProvider.overrideWithValue(repo),
          feedbackProvider.overrideWithValue(RecordingFeedback()),
        ],
        child: const MaterialApp(home: ItemListScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  /// Order the item names appear in the list.
  List<String> names(WidgetTester tester) => [
    for (final t in tester.widgetList<ListTile>(find.byType(ListTile)))
      (t.title as Text).data!,
  ];

  testWidgets('lists every item A–Z with price, stock and barcode', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Items (3)'), findsOneWidget);
    expect(names(tester), ['bubble gum', 'Coffee 3-in-1', 'Pancit Canton']);
    expect(find.text('₱15.00 · Stock: 24 · 4800016644290'), findsOneWidget);
    expect(find.text('₱12.50 · Stock: 7 · 999222'), findsOneWidget);
    expect(find.text('₱2.50 · Stock: 0 · 111'), findsOneWidget);
  });

  testWidgets('search matches name or barcode, ignoring case', (tester) async {
    await pump(tester);
    final search = find.widgetWithText(TextField, 'Search by name or barcode');

    await tester.enterText(search, 'COFFEE');
    await tester.pump();
    expect(names(tester), ['Coffee 3-in-1']);

    await tester.enterText(search, '4800');
    await tester.pump();
    expect(names(tester), ['Pancit Canton']);

    await tester.enterText(search, 'zzz');
    await tester.pump();
    expect(find.text('No items match your search.'), findsOneWidget);

    await tester.enterText(search, '');
    await tester.pump();
    expect(names(tester), hasLength(3));
  });

  testWidgets('no items yet shows an empty state with an add button', (
    tester,
  ) async {
    await pump(tester, items: []);

    expect(find.text('No items yet'), findsOneWidget);
    expect(find.text('Items'), findsOneWidget); // no count in the title
    await tester.tap(find.widgetWithText(FilledButton, 'Add item'));
    await tester.pumpAndSettle();
    expect(find.text('Encode item'), findsOneWidget);
  });

  testWidgets('a load failure offers Try again', (tester) async {
    repo = FakeItemRepo()..failReads = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [itemRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ItemListScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Could not load your items. Please try again.'),
      findsOneWidget,
    );

    repo.failReads = false;
    repo.store[gum.barcode] = gum;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(names(tester), ['bubble gum']);
  });

  group('editing an item from the list', () {
    Future<void> openEdit(WidgetTester tester, String name) async {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping an item opens its form already filled in', (
      tester,
    ) async {
      await pump(tester);
      await openEdit(tester, 'Pancit Canton');

      expect(find.text('Edit item'), findsOneWidget);
      expect(find.text('4800016644290'), findsOneWidget);
      expect(find.text('Pancit Canton'), findsOneWidget);
      expect(find.text('15.00'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('the barcode is locked and explained', (tester) async {
      await pump(tester);
      await openEdit(tester, 'Pancit Canton');

      final barcodeField = tester.widget<TextField>(
        find.descendant(of: field('Barcode'), matching: find.byType(TextField)),
      );
      expect(barcodeField.readOnly, isTrue);
      expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
      expect(find.textContaining("can't be changed"), findsOneWidget);
    });

    testWidgets('saving changes updates the list and closes the form', (
      tester,
    ) async {
      await pump(tester);
      await openEdit(tester, 'Pancit Canton');

      await tester.enterText(field('Item name'), 'Pancit Canton Chilimansi');
      await tester.enterText(field('Price'), '16.75');
      await tester.enterText(field('Stock quantity (optional)'), '30');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Back on the list, showing the new values.
      expect(find.text('Edit item'), findsNothing);
      expect(find.text('Pancit Canton Chilimansi'), findsOneWidget);
      expect(find.text('₱16.75 · Stock: 30 · 4800016644290'), findsOneWidget);
      expect(find.text('Items (3)'), findsOneWidget); // edited, not duplicated
      final saved = repo.store[noodles.barcode]!;
      expect(saved.name, 'Pancit Canton Chilimansi');
      expect(saved.priceCents, 1675);
      expect(saved.stockQty, 30);
      expect(repo.upserts, 1);
    });

    testWidgets('the same checks apply when editing', (tester) async {
      await pump(tester);
      await openEdit(tester, 'Pancit Canton');

      await tester.enterText(field('Item name'), '   ');
      await tester.enterText(field('Price'), '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Price must be greater than 0'), findsOneWidget);
      expect(find.text('Edit item'), findsOneWidget); // still editing
      expect(repo.upserts, 0);
    });

    testWidgets('leaving without saving changes nothing', (tester) async {
      await pump(tester);
      await openEdit(tester, 'Pancit Canton');
      await tester.enterText(field('Item name'), 'Something else');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Pancit Canton'), findsOneWidget);
      expect(repo.upserts, 0);
    });

    testWidgets('deleting from the form removes it from the list', (
      tester,
    ) async {
      await pump(tester);
      await openEdit(tester, 'bubble gum');

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit item'), findsNothing);
      expect(names(tester), ['Coffee 3-in-1', 'Pancit Canton']);
      expect(find.text('Items (2)'), findsOneWidget);
      expect(repo.deleted, ['111']);
    });

    testWidgets('a failed save keeps the form open with the edits', (
      tester,
    ) async {
      await pump(tester);
      await openEdit(tester, 'Pancit Canton');
      await tester.enterText(field('Item name'), 'New name');
      repo.failWrites = true;

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Edit item'), findsOneWidget);
      expect(find.text('New name'), findsOneWidget);
      expect(
        find.text('Could not save the item. Please try again.'),
        findsOneWidget,
      );
    });
  });

  group('adding from the list', () {
    testWidgets('the add button opens a blank form', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Add item').first);
      await tester.pumpAndSettle();

      expect(find.text('Encode item'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(field('Barcode')).controller!.text,
        '',
      );
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('adding keeps the form open for the next one; list updates', (
      tester,
    ) async {
      await pump(tester, items: [gum]);
      await tester.tap(find.text('Add item').first);
      await tester.pumpAndSettle();

      await tester.enterText(field('Barcode'), '555');
      await tester.enterText(field('Item name'), 'Zebra cake');
      await tester.enterText(field('Price'), '9');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Encode item'), findsOneWidget); // ready for another
      expect(
        tester.widget<TextFormField>(field('Barcode')).controller!.text,
        '',
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(names(tester), ['bubble gum', 'Zebra cake']);
      expect(find.text('Items (2)'), findsOneWidget);
    });
  });
}
