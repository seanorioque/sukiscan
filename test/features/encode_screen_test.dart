import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/data/item_repository.dart';
import 'package:sukiscan/domain/item.dart';
import 'package:sukiscan/features/encode/encode_screen.dart';

class FakeRepo implements ItemRepository {
  final store = <String, Item>{};
  var upserts = 0;

  @override
  Future<Item?> get(String barcode, {bool includeDeleted = false}) async =>
      store[barcode];

  @override
  Future<Item> upsert(Item item) async {
    upserts++;
    return store[item.barcode] = item;
  }

  @override
  Future<void> softDelete(String barcode) async {}
}

Future<void> pumpScreen(WidgetTester tester, [FakeRepo? repo]) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemRepositoryProvider.overrideWithValue(repo ?? FakeRepo()),
        ],
        child: const MaterialApp(home: EncodeScreen()),
      ),
    );

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  testWidgets('encode form has fields and accepts typed input', (tester) async {
    await pumpScreen(tester);

    for (final label in [
      'Barcode',
      'Item name',
      'Price',
      'Stock quantity (optional)',
    ]) {
      expect(field(label), findsOneWidget, reason: label);
    }
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);

    await tester.enterText(field('Barcode'), '4800016644290');
    await tester.enterText(field('Price'), '12.5abc');
    await tester.enterText(field('Stock quantity (optional)'), '2x4');
    expect(find.text('4800016644290'), findsOneWidget);
    expect(find.text('12.5'), findsOneWidget); // letters filtered out
    expect(find.text('24'), findsOneWidget); // digits only
  });

  testWidgets('empty form shows required errors and does not save', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Barcode is required'), findsOneWidget);
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Enter a valid price'), findsOneWidget);
    expect(find.text('Item saved'), findsNothing);
  });

  const noodles = Item(
    barcode: '4800016644290',
    name: 'Pancit Canton',
    priceCents: 1500,
    stockQty: 24,
  );

  testWidgets('existing barcode loads into edit mode and updates in place', (
    tester,
  ) async {
    final repo = FakeRepo()..store[noodles.barcode] = noodles;
    await pumpScreen(tester, repo);

    await tester.enterText(field('Barcode'), noodles.barcode);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Edit item'), findsOneWidget);
    expect(find.text('Pancit Canton'), findsOneWidget);
    expect(find.text('15.00'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);

    await tester.enterText(field('Price'), '16');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.upserts, 1);
    expect(repo.store, hasLength(1));
    expect(repo.store[noodles.barcode]!.priceCents, 1600);
    expect(find.text('Encode item'), findsOneWidget); // back to add mode
  });

  testWidgets(
    'save with an unblurred existing barcode loads it, no overwrite',
    (tester) async {
      final repo = FakeRepo()..store[noodles.barcode] = noodles;
      await pumpScreen(tester, repo);

      // Barcode entered last, so the field never loses focus before Save.
      await tester.enterText(field('Item name'), 'Something else');
      await tester.enterText(field('Price'), '1');
      await tester.enterText(field('Barcode'), noodles.barcode);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.upserts, 0);
      expect(repo.store[noodles.barcode]!.name, 'Pancit Canton');
      expect(
        find.text('Pancit Canton'),
        findsOneWidget,
      ); // form now shows saved item
      expect(find.text('Edit item'), findsOneWidget);
    },
  );

  testWidgets('new barcode saves as a new item', (tester) async {
    final repo = FakeRepo();
    await pumpScreen(tester, repo);

    await tester.enterText(field('Barcode'), '123');
    await tester.enterText(field('Item name'), 'Gum');
    await tester.enterText(field('Price'), '2.5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.store['123']!.priceCents, 250);
    expect(repo.store['123']!.stockQty, 0);
  });

  testWidgets('blank-space barcode/name and zero price are rejected', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.enterText(field('Barcode'), '   ');
    await tester.enterText(field('Item name'), '  ');
    await tester.enterText(field('Price'), '0');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Barcode is required'), findsOneWidget);
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Price must be greater than 0'), findsOneWidget);
  });
}
