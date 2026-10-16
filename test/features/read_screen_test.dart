import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/data/item_repository.dart';
import 'package:sukiscan/domain/item.dart';
import 'package:sukiscan/features/read/read_screen.dart';
import '../helpers/fake_item_repo.dart';

void main() {
  const noodles = Item(
    barcode: '4800016644290',
    name: 'Pancit Canton',
    priceCents: 123450,
    stockQty: 24,
  );

  late void Function(String) scan;
  late FakeItemRepo repo;

  Future<void> pump(WidgetTester tester) async {
    repo = FakeItemRepo()..store[noodles.barcode] = noodles;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [itemRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: ReadScreen(
            scannerBuilder: (onScan) {
              scan = onScan;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
  }

  testWidgets('shows a prompt before any scan', (tester) async {
    await pump(tester);
    expect(find.text('Point the camera at a barcode'), findsOneWidget);
  });

  testWidgets('scan of a known barcode shows name, price and stock', (
    tester,
  ) async {
    await pump(tester);
    scan(noodles.barcode);
    await tester.pumpAndSettle();

    expect(find.text('Pancit Canton'), findsOneWidget);
    expect(find.text('₱1,234.50'), findsOneWidget);
    expect(find.text('Stock: 24'), findsOneWidget);
  });

  testWidgets('scan of an unknown barcode shows not found', (tester) async {
    await pump(tester);
    scan('999');
    await tester.pumpAndSettle();

    expect(find.text('Not found'), findsOneWidget);
    expect(find.text('999'), findsOneWidget);
  });

  testWidgets('not found offers to encode, pre-filled, then rescans fresh', (
    tester,
  ) async {
    await pump(tester);
    scan('999');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not found — encode this item?'));
    await tester.pumpAndSettle();
    expect(find.text('Encode item'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Barcode'))
          .controller!
          .text,
      '999',
    );

    // Back on Read: the same code is looked up again, now that it may exist.
    final before = repo.lookups;
    repo.store['999'] = const Item(
      barcode: '999',
      name: 'Gum',
      priceCents: 250,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Point the camera at a barcode'), findsOneWidget);
    scan('999');
    await tester.pumpAndSettle();
    expect(repo.lookups, before + 1);
    expect(find.text('Gum'), findsOneWidget);
  });

  testWidgets('repeated frames of the same code look up once', (tester) async {
    await pump(tester);
    scan(noodles.barcode);
    scan(noodles.barcode);
    scan(noodles.barcode);
    await tester.pumpAndSettle();
    expect(repo.lookups, 1);

    scan('999'); // a different code is looked up again
    await tester.pumpAndSettle();
    expect(repo.lookups, 2);
    expect(find.text('Not found'), findsOneWidget);
  });
}
