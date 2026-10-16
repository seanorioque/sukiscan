import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/data/device_auth.dart';
import 'package:sukiscan/data/sale_repository.dart';
import 'package:sukiscan/domain/sale.dart';
import 'package:sukiscan/features/history/history_screen.dart';
import 'package:sukiscan/shared/app_feedback.dart';

import '../helpers/fake_device_auth.dart';
import '../helpers/fake_sale_repo.dart';
import '../helpers/recording_feedback.dart';

void main() {
  late FakeSaleRepo repo;
  late FakeDeviceAuth auth;
  final feedback = RecordingFeedback();
  setUp(feedback.events.clear);

  // 2026-10-16 09:30 local time.
  final at = DateTime(2026, 10, 16, 9, 30).millisecondsSinceEpoch;

  SaleSummary sale(String id, int total, {int items = 1, int? cash}) =>
      SaleSummary(
        id: id,
        createdAt: at,
        totalCents: total,
        itemCount: items,
        cashCents: cash,
      );

  /// [count] plain sales s1..sN (₱10.00, ₱20.00, ...), plus any [extra].
  Future<void> pump(
    WidgetTester tester, {
    int count = 3,
    List<SaleSummary> extra = const [],
  }) async {
    repo = FakeSaleRepo();
    auth = FakeDeviceAuth();
    for (var i = 1; i <= count; i++) {
      repo.sales.add(sale('s$i', i * 1000, items: i));
    }
    repo.sales.addAll(extra);
    repo.lineItems['s1'] = const [
      SaleLine(barcode: 'A', name: 'Noodles', unitPriceCents: 1000, qty: 1),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saleRepositoryProvider.overrideWithValue(repo),
          deviceAuthProvider.overrideWithValue(auth),
          feedbackProvider.overrideWithValue(feedback),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> tapTip(WidgetTester tester, String tip) async {
    await tester.tap(find.byTooltip(tip));
    await tester.pumpAndSettle();
  }

  testWidgets('lists each purchase with its total, date and item count', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('₱10.00'), findsOneWidget);
    expect(find.text('₱30.00'), findsOneWidget);
    expect(find.text('Oct 16, 2026 · 9:30 AM · 1 item'), findsOneWidget);
    expect(find.text('Oct 16, 2026 · 9:30 AM · 3 items'), findsOneWidget);
  });

  testWidgets('no purchases shows an empty state and no select button', (
    tester,
  ) async {
    await pump(tester, count: 0);
    expect(find.text('No purchases yet'), findsOneWidget);
    expect(find.byTooltip('Select purchases'), findsNothing);
  });

  testWidgets('opening a purchase shows what was sold', (tester) async {
    await pump(tester);
    await tapText(tester, '₱10.00');
    expect(find.text('1 × Noodles'), findsOneWidget);
  });

  testWidgets('cash and change show when cash was entered', (tester) async {
    await pump(
      tester,
      count: 0,
      extra: [sale('c1', 3250, items: 3, cash: 5000)],
    );
    await tapText(tester, '₱32.50');
    expect(find.text('₱50.00'), findsOneWidget); // cash
    expect(find.text('₱17.50'), findsOneWidget); // change
  });

  group('single delete', () {
    Future<void> deleteFirst(WidgetTester tester) async {
      await tapText(tester, '₱10.00'); // open it
      await tapText(tester, 'Delete'); // the card's button
    }

    testWidgets('asks to confirm, then for the phone lock, then deletes', (
      tester,
    ) async {
      await pump(tester);
      await deleteFirst(tester);
      expect(find.text('Delete this purchase?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(auth.reasons, hasLength(1));
      expect(repo.deleted, ['s1']);
      expect(find.text('₱10.00'), findsNothing);
      expect(find.text('Deleted 1 purchase'), findsOneWidget);
      expect(feedback.events, ['success']);
    });

    testWidgets('cancelling the confirmation never asks for the lock', (
      tester,
    ) async {
      await pump(tester);
      await deleteFirst(tester);
      await tapText(tester, 'Cancel');

      expect(auth.reasons, isEmpty);
      expect(repo.deleted, isEmpty);
    });

    testWidgets('a failed or cancelled lock check deletes nothing', (
      tester,
    ) async {
      await pump(tester);
      auth.outcome = AuthOutcome.cancelled;
      await deleteFirst(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repo.deleted, isEmpty);
      expect(find.text('₱10.00'), findsWidgets);
      expect(find.text('Nothing was deleted.'), findsOneWidget);
    });

    testWidgets('a phone with no screen lock is told to set one', (
      tester,
    ) async {
      await pump(tester);
      auth.outcome = AuthOutcome.noScreenLock;
      await deleteFirst(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repo.deleted, isEmpty);
      expect(find.textContaining('Set a screen lock'), findsOneWidget);
      expect(feedback.events, ['error']);
    });

    testWidgets('a lock error deletes nothing and says so', (tester) async {
      await pump(tester);
      auth.outcome = AuthOutcome.failed;
      await deleteFirst(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repo.deleted, isEmpty);
      expect(find.textContaining('Nothing was deleted'), findsOneWidget);
    });

    testWidgets('a database failure is reported', (tester) async {
      await pump(tester);
      repo.failDelete = true;
      await deleteFirst(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete. Nothing was changed.'),
        findsOneWidget,
      );
      expect(find.text('₱10.00'), findsWidgets);
      expect(feedback.events, ['error']);
    });
  });

  group('multiple delete', () {
    testWidgets('select several, one lock check, all deleted', (tester) async {
      await pump(tester);
      await tapTip(tester, 'Select purchases');
      await tapText(tester, '₱10.00');
      await tapText(tester, '₱30.00');
      expect(find.text('2 selected'), findsOneWidget);

      await tapTip(tester, 'Delete selected');
      expect(find.text('Delete 2 purchases?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(auth.reasons, hasLength(1)); // once, not per purchase
      expect(repo.deleted.toSet(), {'s1', 's3'});
      expect(find.text('₱20.00'), findsOneWidget); // s2 stays
      expect(find.text('Deleted 2 purchases'), findsOneWidget);
      expect(find.text('Purchase history'), findsOneWidget); // left selecting
    });

    testWidgets('select all ticks everything', (tester) async {
      await pump(tester);
      await tapTip(tester, 'Select purchases');
      expect(find.text('0 selected'), findsOneWidget);

      await tapTip(tester, 'Select all');
      expect(find.text('3 selected'), findsOneWidget);
    });

    testWidgets('delete is off until something is ticked', (tester) async {
      await pump(tester);
      await tapTip(tester, 'Select purchases');
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('closing selection keeps everything', (tester) async {
      await pump(tester);
      await tapTip(tester, 'Select purchases');
      await tapText(tester, '₱10.00');
      await tapTip(tester, 'Cancel selection');

      expect(find.text('Purchase history'), findsOneWidget);
      expect(repo.deleted, isEmpty);
    });
  });
}
