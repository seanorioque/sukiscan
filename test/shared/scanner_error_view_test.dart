import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tindascan/shared/scanner_view.dart';

void main() {
  var retries = 0;

  Future<void> show(WidgetTester tester, MobileScannerErrorCode code) {
    retries = 0;
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScannerErrorView(
            error: MobileScannerException(errorCode: code),
            onRetry: () => retries++,
          ),
        ),
      ),
    );
  }

  testWidgets('permission denied explains where to allow the camera', (
    tester,
  ) async {
    await show(tester, MobileScannerErrorCode.permissionDenied);
    expect(find.textContaining('Camera permission is needed'), findsOneWidget);
    expect(find.textContaining('Settings > Apps > TindaScan'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('an unsupported camera says so and offers no pointless Retry', (
    tester,
  ) async {
    await show(tester, MobileScannerErrorCode.unsupported);
    expect(find.textContaining("can't be used for scanning"), findsOneWidget);
    expect(find.textContaining('type barcodes in by hand'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('other camera errors suggest closing other camera apps', (
    tester,
  ) async {
    await show(tester, MobileScannerErrorCode.genericError);
    expect(find.textContaining('could not start'), findsOneWidget);
    expect(find.textContaining('Close other apps'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });
}
