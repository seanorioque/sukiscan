import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/app.dart';

void main() {
  testWidgets('home menu navigates to a module', (tester) async {
    await tester.pumpWidget(const SukiScanApp());

    for (final label in ['Encode', 'Read', 'Sell', 'Sync']) {
      expect(find.text(label), findsOneWidget);
    }

    // Sync is the one module that needs no camera or database to open.
    await tester.tap(find.text('Sync'));
    await tester.pumpAndSettle();
    expect(find.text('Send items'), findsOneWidget);
  });
}
