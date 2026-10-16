import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/features/encode/encode_screen.dart';

void main() {
  testWidgets('encode form has fields and accepts typed input', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EncodeScreen()));

    for (final label in ['Barcode', 'Item name', 'Price', 'Stock quantity (optional)']) {
      expect(find.widgetWithText(TextFormField, label), findsOneWidget, reason: label);
    }
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Barcode'), '4800016644290');
    await tester.enterText(find.widgetWithText(TextFormField, 'Price'), '12.5abc');
    await tester.enterText(find.widgetWithText(TextFormField, 'Stock quantity (optional)'), '2x4');
    expect(find.text('4800016644290'), findsOneWidget);
    expect(find.text('12.5'), findsOneWidget); // letters filtered out
    expect(find.text('24'), findsOneWidget); // digits only
  });
}
