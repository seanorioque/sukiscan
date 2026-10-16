import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/app.dart';
import 'package:sukiscan/core/theme.dart';
import 'package:sukiscan/data/item_repository.dart';
import 'package:sukiscan/domain/item.dart';
import 'package:sukiscan/shared/app_feedback.dart';

import 'helpers/fake_item_repo.dart';
import 'helpers/recording_feedback.dart';

/// Stands in for the camera and counts how many are on screen at once.
class _CameraProbe extends StatefulWidget {
  const _CameraProbe(this.live);
  final ValueNotifier<int> live;

  @override
  State<_CameraProbe> createState() => _CameraProbeState();
}

class _CameraProbeState extends State<_CameraProbe> {
  @override
  void initState() {
    super.initState();
    widget.live.value++;
  }

  @override
  void dispose() {
    widget.live.value--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  const noodles = Item(
    barcode: 'A',
    name: 'Pancit Canton',
    priceCents: 1500,
    stockQty: 3,
  );
  const gum = Item(barcode: 'B', name: 'Gum', priceCents: 250);

  late void Function(String) scan;
  late ValueNotifier<int> cameras;

  Future<void> pumpApp(WidgetTester tester) async {
    cameras = ValueNotifier(0);
    final repo = FakeItemRepo()
      ..store['A'] = noodles
      ..store['B'] = gum;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemRepositoryProvider.overrideWithValue(repo),
          feedbackProvider.overrideWithValue(RecordingFeedback()),
        ],
        child: SukiScanApp(
          scannerBuilder: (onScan) {
            scan = onScan;
            return _CameraProbe(cameras);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  int selectedTab(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  Future<void> goTo(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('top bar', () {
    testWidgets('shows the SukiScan wordmark and a Sync button on the right', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.byKey(const Key('brand-logo')), findsOneWidget);
      expect(find.bySemanticsLabel('SukiScan'), findsOneWidget);
      final sync = find.byTooltip('Sync with another phone');
      expect(sync, findsOneWidget);

      // Far right: nothing in the bar sits to the right of it.
      final bar = tester.getRect(find.byType(AppBar));
      expect(tester.getRect(sync).right, greaterThan(bar.right - 64));
    });

    testWidgets('the wordmark is on every tab', (tester) async {
      await pumpApp(tester);
      for (final tab in ['Encode', 'Read', 'Sell']) {
        await goTo(tester, tab);
        expect(
          find.byKey(const Key('brand-logo')),
          findsOneWidget,
          reason: tab,
        );
      }
    });

    testWidgets('Sync opens the sync screen and back returns to the tab', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Sync with another phone'));
      await tester.pumpAndSettle();
      expect(find.text('Send items'), findsOneWidget);
      expect(find.text('Receive items'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(selectedTab(tester), 2);
    });
  });

  group('bottom navigation', () {
    testWidgets('has the three modes and opens on Sell', (tester) async {
      await pumpApp(tester);

      final bar = find.byType(NavigationBar);
      for (final label in ['Encode', 'Read', 'Sell']) {
        expect(
          find.descendant(of: bar, matching: find.text(label)),
          findsOneWidget,
          reason: label,
        );
      }
      expect(selectedTab(tester), 2);
      expect(find.text('Scan items to add them to the sale'), findsOneWidget);
    });

    testWidgets('each tab shows its own screen', (tester) async {
      await pumpApp(tester);

      await goTo(tester, 'Encode');
      expect(selectedTab(tester), 0);
      expect(find.text('Items (2)'), findsOneWidget);
      expect(find.text('Pancit Canton'), findsOneWidget);

      await goTo(tester, 'Read');
      expect(selectedTab(tester), 1);
      expect(find.text('Point the camera at a barcode'), findsOneWidget);

      await goTo(tester, 'Sell');
      expect(selectedTab(tester), 2);
      expect(find.text('Checkout'), findsOneWidget);
    });

    testWidgets('only one camera runs at a time', (tester) async {
      await pumpApp(tester);
      expect(cameras.value, 1); // Sell

      await goTo(tester, 'Encode');
      expect(cameras.value, 0); // the items list has no camera

      await goTo(tester, 'Read');
      expect(cameras.value, 1);

      await goTo(tester, 'Sell');
      expect(cameras.value, 1);
    });

    testWidgets('the active tab is highlighted with the primary accent', (
      tester,
    ) async {
      await pumpApp(tester);
      final context = tester.element(find.byType(NavigationBar));
      final scheme = Theme.of(context).colorScheme;
      final theme = Theme.of(context).navigationBarTheme;

      expect(theme.indicatorColor, scheme.primary);
      expect(theme.indicatorShape, isA<StadiumBorder>());
    });

    testWidgets('the cart badge counts lines and survives tab switches', (
      tester,
    ) async {
      await pumpApp(tester);
      final badge = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(Badge),
      );
      expect(tester.widget<Badge>(badge).isLabelVisible, isFalse);

      scan('A');
      scan('A'); // same item: still one line
      scan('B');
      await tester.pumpAndSettle();
      expect(tester.widget<Badge>(badge).isLabelVisible, isTrue);
      expect(
        find.descendant(of: badge, matching: find.text('2')),
        findsOneWidget,
      );

      await goTo(tester, 'Encode');
      await goTo(tester, 'Sell');
      expect(find.text('Pancit Canton'), findsOneWidget); // cart kept
      expect(find.text('Gum'), findsOneWidget);
    });
  });

  group('look', () {
    testWidgets('cards are rounded and outlined', (tester) async {
      await pumpApp(tester);
      await goTo(tester, 'Encode');

      final card = tester.widget<Card>(find.byType(Card).first);
      final shape = card.shape as RoundedRectangleBorder?;
      // Card styling comes from the shared theme, not each screen.
      expect(shape, isNull);
      final theme = Theme.of(tester.element(find.byType(Card).first)).cardTheme;
      final themed = theme.shape as RoundedRectangleBorder;
      expect(themed.borderRadius, BorderRadius.circular(18));
      expect(themed.side.width, greaterThan(0));
    });

    test('light and dark themes share the accent and both build', () {
      final light = appTheme(Brightness.light);
      final dark = appTheme(Brightness.dark);
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.useMaterial3, isTrue);
      expect(dark.navigationBarTheme.indicatorColor, dark.colorScheme.primary);
      expect(
        light.navigationBarTheme.indicatorColor,
        light.colorScheme.primary,
      );
    });

    testWidgets('the app renders in dark mode', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpApp(tester);

      final context = tester.element(find.byType(NavigationBar));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(find.byKey(const Key('brand-logo')), findsOneWidget);
    });
  });

  testWidgets('startup error screen explains and offers Try again', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(StartupErrorApp(onRetry: () => retried++));

    expect(find.text("SukiScan couldn't open your items"), findsOneWidget);
    expect(find.textContaining('free storage space'), findsOneWidget);
    expect(find.textContaining('have not been deleted'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    expect(retried, 1);
  });
}
