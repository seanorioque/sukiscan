import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/data/item_repository.dart';
import 'package:sukiscan/domain/item.dart';
import 'package:sukiscan/features/sell/sell_screen.dart';

import '../helpers/fake_item_repo.dart';

void main() {
  const noodles = Item(barcode: 'A', name: 'Noodles', priceCents: 1500);
  const gum = Item(barcode: 'B', name: 'Gum', priceCents: 250);

  late void Function(String) scan;

  Future<void> pump(WidgetTester tester) async {
    final repo = FakeItemRepo()
      ..store['A'] = noodles
      ..store['B'] = gum;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [itemRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: SellScreen(
            scannerBuilder: (onScan) {
              scan = onScan;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
  }

  testWidgets('empty cart shows a prompt and a zero total', (tester) async {
    await pump(tester);
    expect(find.text('Scan items to add them to the sale'), findsOneWidget);
    expect(find.text('₱0.00'), findsOneWidget);
  });

  testWidgets('scan adds a line; scanning again adds +1', (tester) async {
    await pump(tester);

    scan('A');
    await tester.pumpAndSettle();
    expect(find.text('Noodles'), findsOneWidget);
    expect(find.text('₱15.00 each · ₱15.00'), findsOneWidget);

    scan('A');
    await tester.pumpAndSettle();
    expect(find.text('Noodles'), findsOneWidget); // still one line
    expect(find.text('₱15.00 each · ₱30.00'), findsOneWidget);
    expect(find.text('₱30.00'), findsOneWidget); // grand total
  });

  testWidgets('different items get their own lines and the total adds up', (
    tester,
  ) async {
    await pump(tester);
    scan('A');
    scan('B');
    scan('B');
    await tester.pumpAndSettle();

    expect(find.text('Noodles'), findsOneWidget);
    expect(find.text('Gum'), findsOneWidget);
    expect(find.text('₱20.00'), findsOneWidget); // 1500 + 2 * 250
  });

  Finder inLine(String name, Finder what) =>
      find.descendant(of: find.widgetWithText(ListTile, name), matching: what);

  Future<void> tapLine(WidgetTester tester, String name, String tooltip) async {
    await tester.tap(inLine(name, find.byTooltip(tooltip)));
    await tester.pumpAndSettle();
  }

  testWidgets('+ and – change the quantity and the total follows', (
    tester,
  ) async {
    await pump(tester);
    scan('A');
    scan('B');
    await tester.pumpAndSettle(); // 1500 + 250

    await tapLine(tester, 'Noodles', 'Increase');
    await tapLine(tester, 'Noodles', 'Increase');
    expect(inLine('Noodles', find.text('3')), findsOneWidget);
    expect(find.text('₱47.50'), findsOneWidget); // 3 * 1500 + 250

    await tapLine(tester, 'Noodles', 'Decrease');
    expect(inLine('Noodles', find.text('2')), findsOneWidget);
    expect(find.text('₱32.50'), findsOneWidget);
  });

  testWidgets('– at quantity 1 removes the line', (tester) async {
    await pump(tester);
    scan('A');
    scan('B');
    await tester.pumpAndSettle();

    await tapLine(tester, 'Gum', 'Decrease');
    expect(find.text('Gum'), findsNothing);
    expect(find.text('Noodles'), findsOneWidget);
    expect(find.text('₱15.00'), findsNWidgets(1)); // grand total only
  });

  testWidgets('remove deletes the whole line whatever its quantity', (
    tester,
  ) async {
    await pump(tester);
    scan('A');
    scan('A');
    scan('B');
    await tester.pumpAndSettle();

    await tapLine(tester, 'Noodles', 'Remove line');
    expect(find.text('Noodles'), findsNothing);
    expect(find.text('₱2.50'), findsNWidgets(1));
  });

  testWidgets('clear cart asks first, then empties the cart', (tester) async {
    await pump(tester);
    expect(find.byTooltip('Clear cart'), findsNothing); // nothing to clear

    scan('A');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Clear cart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Noodles'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear cart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Noodles'), findsNothing);
    expect(find.text('Scan items to add them to the sale'), findsOneWidget);
    expect(find.text('₱0.00'), findsOneWidget);
    expect(find.byTooltip('Clear cart'), findsNothing);
  });

  testWidgets('unknown barcode is not added and says so', (tester) async {
    await pump(tester);
    scan('nope');
    await tester.pumpAndSettle();

    expect(find.text('Not found: nope'), findsOneWidget);
    expect(find.text('Scan items to add them to the sale'), findsOneWidget);
    expect(find.text('₱0.00'), findsOneWidget);
  });
}
