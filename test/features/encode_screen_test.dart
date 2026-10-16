import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/features/encode/encode_screen.dart';

Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: EncodeScreen())),
    );

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  testWidgets('encode form has fields and accepts typed input', (tester) async {
    await pumpScreen(tester);

    for (final label in ['Barcode', 'Item name', 'Price', 'Stock quantity (optional)']) {
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

  testWidgets('empty form shows required errors and does not save', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Barcode is required'), findsOneWidget);
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Enter a valid price'), findsOneWidget);
    expect(find.text('Item saved'), findsNothing);
  });

  testWidgets('blank-space barcode/name and zero price are rejected', (tester) async {
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
