import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/app.dart';

void main() {
  testWidgets('home menu navigates to a module', (tester) async {
    await tester.pumpWidget(const SukiScanApp());

    for (final label in ['Encode', 'Read', 'Sell', 'Sync']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Sync')); // still a placeholder page
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsOneWidget);
  });
}
