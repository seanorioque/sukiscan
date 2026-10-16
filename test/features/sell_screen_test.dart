import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/data/item_repository.dart';
import 'package:sukiscan/data/sale_repository.dart';
import 'package:sukiscan/domain/item.dart';
import 'package:sukiscan/features/sell/sell_screen.dart';

import '../helpers/fake_item_repo.dart';
import '../helpers/fake_sale_repo.dart';

void main() {
  const noodles = Item(barcode: 'A', name: 'Noodles', priceCents: 1500);
  const gum = Item(barcode: 'B', name: 'Gum', priceCents: 250);

  late void Function(String) scan;
  late FakeSaleRepo sales;

  late FakeItemRepo items; // the fake behind the current screen

  Future<void> pump(WidgetTester tester, {bool withItems = true}) async {
    final repo = items = FakeItemRepo();
    if (withItems) {
      repo.store
        ..['A'] = noodles
        ..['B'] = gum;
    }
    sales = FakeSaleRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemRepositoryProvider.overrideWithValue(repo),
          saleRepositoryProvider.overrideWithValue(sales),
        ],
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

  testWidgets(
    'empty cart with items shows the scan hint, not the no-items hint',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('Scan items to add them to the sale'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
      expect(find.text('No items yet'), findsNothing);
    },
  );

  testWidgets(
    'no saved items: explains and offers Encode; fills in once one is saved',
    (tester) async {
      await pump(tester, withItems: false);
      await tester.pumpAndSettle();

      expect(find.text('No items yet'), findsOneWidget);
      expect(find.text('Scan items to add them to the sale'), findsNothing);

      await tester.tap(find.text('Encode an item'));
      await tester.pumpAndSettle();
      expect(find.text('Encode item'), findsOneWidget); // the Encode screen

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Barcode'),
        '123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Item name'),
        'Gum',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Price'),
        '2.5',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(items.store, hasLength(1));

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('No items yet'), findsNothing); // count refreshed
      expect(find.text('Scan items to add them to the sale'), findsOneWidget);
    },
  );

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

  // --- checkout (cart of Noodles + Gum = ₱17.50) ---

  Future<void> openCheckout(WidgetTester tester) async {
    scan('A');
    scan('B');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Checkout'));
    await tester.pumpAndSettle();
  }

  Future<void> typeCash(WidgetTester tester, String value) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Cash tendered (optional)'),
      value,
    );
    await tester.pumpAndSettle();
  }

  Finder confirmButton() => find.widgetWithText(FilledButton, 'Confirm sale');
  bool confirmEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(confirmButton()).onPressed != null;

  testWidgets('checkout is disabled while the cart is empty', (tester) async {
    await pump(tester);
    final button = find.widgetWithText(FilledButton, 'Checkout');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });

  testWidgets('confirm without cash saves the sale and clears the cart', (
    tester,
  ) async {
    await pump(tester);
    await openCheckout(tester);
    expect(find.text('Change due'), findsNothing);

    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    expect(sales.calls, hasLength(1));
    expect(sales.calls.single.cashCents, isNull);
    expect(sales.calls.single.cart.totalCents, 1750);
    expect(find.text('Sale saved'), findsOneWidget);
    expect(find.text('Scan items to add them to the sale'), findsOneWidget);
    expect(find.text('Cash tendered (optional)'), findsNothing); // sheet closed
  });

  testWidgets('cash tendered shows change due and is passed to checkout', (
    tester,
  ) async {
    await pump(tester);
    await openCheckout(tester);
    await typeCash(tester, '20');

    expect(find.text('Change due ₱2.50'), findsOneWidget);
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    expect(sales.calls.single.cashCents, 2000);
    expect(find.text('Sale saved — change ₱2.50'), findsOneWidget);
  });

  testWidgets('exact cash gives zero change', (tester) async {
    await pump(tester);
    await openCheckout(tester);
    await typeCash(tester, '17.5');
    expect(find.text('Change due ₱0.00'), findsOneWidget);
    expect(confirmEnabled(tester), isTrue);
  });

  testWidgets('cash below the total blocks confirm', (tester) async {
    await pump(tester);
    await openCheckout(tester);
    await typeCash(tester, '10');

    expect(find.text('Short by ₱7.50'), findsOneWidget);
    expect(confirmEnabled(tester), isFalse);
  });

  testWidgets('malformed cash blocks confirm', (tester) async {
    await pump(tester);
    await openCheckout(tester);
    await typeCash(tester, '1.2.3');

    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(confirmEnabled(tester), isFalse);
  });

  testWidgets('a failed save keeps the cart and shows an error', (
    tester,
  ) async {
    await pump(tester);
    sales.fail = true;
    await openCheckout(tester);

    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save the sale. Please try again.'),
      findsOneWidget,
    );
    expect(confirmEnabled(tester), isTrue); // can retry

    // Cart is intact behind the sheet.
    sales.fail = false;
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();
    expect(sales.calls, hasLength(1));
    expect(find.text('Scan items to add them to the sale'), findsOneWidget);
  });

  // --- manual barcode entry ---

  Future<void> openManual(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Type barcode'));
    await tester.pumpAndSettle();
  }

  Future<void> typeBarcode(WidgetTester tester, String code) async {
    await tester.enterText(find.widgetWithText(TextField, 'Barcode'), code);
    await tester.pump();
  }

  testWidgets('typing a known barcode adds it like a scan', (tester) async {
    await pump(tester);
    await openManual(tester);
    await typeBarcode(tester, ' A ');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Type barcode'), findsNothing); // dialog closed
    expect(find.text('Noodles'), findsOneWidget);
    expect(find.text('₱15.00 each · ₱15.00'), findsOneWidget);

    await openManual(tester); // typing it again is +1
    await typeBarcode(tester, 'A');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('₱15.00 each · ₱30.00'), findsOneWidget);
  });

  testWidgets('typing an unknown barcode raises the not-found alert', (
    tester,
  ) async {
    await pump(tester);
    await openManual(tester);
    await typeBarcode(tester, 'zzz');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Item not found'), findsOneWidget);
    expect(find.textContaining('zzz'), findsOneWidget);
    expect(find.text('Scan items to add them to the sale'), findsOneWidget);
  });

  testWidgets('blank entry shows an error; Cancel adds nothing', (
    tester,
  ) async {
    await pump(tester);
    await openManual(tester);
    await typeBarcode(tester, '   ');
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('Enter a barcode'), findsOneWidget);
    expect(find.text('Type barcode'), findsWidgets); // dialog still open

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Scan items to add them to the sale'), findsOneWidget);
  });

  testWidgets('camera scans are ignored while the entry dialog is open', (
    tester,
  ) async {
    await pump(tester);
    await openManual(tester);

    scan('A');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Noodles'), findsNothing);

    scan('A'); // and works again afterwards
    await tester.pumpAndSettle();
    expect(find.text('Noodles'), findsOneWidget);
  });

  testWidgets('unknown barcode raises an alert and is not added', (
    tester,
  ) async {
    await pump(tester);
    scan('nope');
    await tester.pumpAndSettle();

    expect(find.text('Item not found'), findsOneWidget);
    expect(find.textContaining('nope'), findsOneWidget);
    expect(find.text('Encode item'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Item not found'), findsNothing);
    expect(find.text('Scan items to add them to the sale'), findsOneWidget);
    expect(find.text('₱0.00'), findsOneWidget);
  });

  testWidgets('scans are ignored while the alert is open (no stacking)', (
    tester,
  ) async {
    await pump(tester);
    scan('first');
    await tester.pumpAndSettle();

    scan('second'); // unknown: no second alert
    scan('A'); // known: not added behind the alert
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('first'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Scan items to add them to the sale'), findsOneWidget);

    // Scanning works again afterwards.
    scan('A');
    await tester.pumpAndSettle();
    expect(find.text('Noodles'), findsOneWidget);
  });

  testWidgets(
    '"Encode item" opens Encode with the barcode, then back to Sell',
    (tester) async {
      await pump(tester);
      scan('newcode');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Encode item'));
      await tester.pumpAndSettle();
      expect(find.text('Encode item'), findsOneWidget); // Encode screen title
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Barcode'),
            )
            .controller!
            .text,
        'newcode',
      );

      scan('A'); // Sell's camera is still running underneath: ignored
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Sell'), findsOneWidget);
      expect(find.text('Noodles'), findsNothing);

      scan('A');
      await tester.pumpAndSettle();
      expect(find.text('Noodles'), findsOneWidget);
    },
  );
}
