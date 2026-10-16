import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/data/item_repository.dart';
import 'package:sukiscan/domain/item.dart';
import 'package:sukiscan/features/encode/encode_screen.dart';
import 'package:sukiscan/shared/app_feedback.dart';

import '../helpers/fake_item_repo.dart';
import '../helpers/recording_feedback.dart';

final feedback = RecordingFeedback();

Future<void> pumpScreen(WidgetTester tester, [FakeItemRepo? repo]) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemRepositoryProvider.overrideWithValue(repo ?? FakeItemRepo()),
          feedbackProvider.overrideWithValue(feedback),
        ],
        child: const MaterialApp(home: EncodeScreen()),
      ),
    );

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  setUp(feedback.events.clear);

  testWidgets('encode form has fields and accepts typed input', (tester) async {
    await pumpScreen(tester);

    for (final label in [
      'Barcode',
      'Item name',
      'Price',
      'Stock quantity (optional)',
    ]) {
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

  testWidgets('empty form shows required errors and does not save', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Barcode is required'), findsOneWidget);
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Enter a valid price'), findsOneWidget);
    expect(find.text('Item saved'), findsNothing);
  });

  const noodles = Item(
    barcode: '4800016644290',
    name: 'Pancit Canton',
    priceCents: 1500,
    stockQty: 24,
  );

  testWidgets('existing barcode loads into edit mode and updates in place', (
    tester,
  ) async {
    final repo = FakeItemRepo()..store[noodles.barcode] = noodles;
    await pumpScreen(tester, repo);

    await tester.enterText(field('Barcode'), noodles.barcode);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Edit item'), findsOneWidget);
    expect(find.text('Pancit Canton'), findsOneWidget);
    expect(find.text('15.00'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);

    await tester.enterText(field('Price'), '16');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.upserts, 1);
    expect(repo.store, hasLength(1));
    expect(repo.store[noodles.barcode]!.priceCents, 1600);
    expect(find.text('Encode item'), findsOneWidget); // back to add mode
  });

  testWidgets(
    'save with an unblurred existing barcode loads it, no overwrite',
    (tester) async {
      final repo = FakeItemRepo()..store[noodles.barcode] = noodles;
      await pumpScreen(tester, repo);

      // Barcode entered last, so the field never loses focus before Save.
      await tester.enterText(field('Item name'), 'Something else');
      await tester.enterText(field('Price'), '1');
      await tester.enterText(field('Barcode'), noodles.barcode);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.upserts, 0);
      expect(repo.store[noodles.barcode]!.name, 'Pancit Canton');
      expect(
        find.text('Pancit Canton'),
        findsOneWidget,
      ); // form now shows saved item
      expect(find.text('Edit item'), findsOneWidget);
    },
  );

  testWidgets('delete button only shows in edit mode and soft-deletes', (
    tester,
  ) async {
    final repo = FakeItemRepo()..store[noodles.barcode] = noodles;
    await pumpScreen(tester, repo);
    expect(find.text('Delete'), findsNothing);

    await tester.enterText(field('Barcode'), noodles.barcode);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);

    // Cancel keeps the item.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);

    // Confirm deletes and resets the form.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.deleted, [noodles.barcode]);
    expect(find.text('Encode item'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('new barcode saves as a new item', (tester) async {
    final repo = FakeItemRepo();
    await pumpScreen(tester, repo);

    await tester.enterText(field('Barcode'), '123');
    await tester.enterText(field('Item name'), 'Gum');
    await tester.enterText(field('Price'), '2.5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.store['123']!.priceCents, 250);
    expect(repo.store['123']!.stockQty, 0);
  });

  testWidgets('blank-space barcode/name and zero price are rejected', (
    tester,
  ) async {
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

  group('feedback', () {
    Future<void> fillForm(WidgetTester tester) async {
      await tester.enterText(field('Barcode'), '123');
      await tester.enterText(field('Item name'), 'Gum');
      await tester.enterText(field('Price'), '2.5');
    }

    testWidgets('a saved item gives the success cue', (tester) async {
      await pumpScreen(tester);
      await fillForm(tester);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(feedback.events, ['success']);
    });

    testWidgets('a failed save buzzes', (tester) async {
      await pumpScreen(tester, FakeItemRepo()..failWrites = true);
      await fillForm(tester);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(feedback.events, ['error']);
    });

    testWidgets('a form that fails validation stays silent', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(feedback.events, isEmpty); // the red field text is the feedback
    });

    testWidgets('a deleted item gives the success cue', (tester) async {
      final repo = FakeItemRepo()
        ..store['A'] = const Item(
          barcode: 'A',
          name: 'Noodles',
          priceCents: 1500,
        );
      await pumpScreen(tester, repo);
      await tester.enterText(field('Barcode'), 'A');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();
      expect(feedback.events, ['success']);
    });
  });

  group('database failures', () {
    Future<void> fillForm(WidgetTester tester) async {
      await tester.enterText(field('Barcode'), '123');
      await tester.enterText(field('Item name'), 'Gum');
      await tester.enterText(field('Price'), '2.5');
    }

    testWidgets('a failed save says so and keeps the form for a retry', (
      tester,
    ) async {
      final repo = FakeItemRepo()..failWrites = true;
      await pumpScreen(tester, repo);
      await fillForm(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save the item. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Item saved'), findsNothing);
      expect(find.text('Gum'), findsOneWidget); // nothing to retype
      expect(repo.store, isEmpty);

      repo.failWrites = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.store['123']!.name, 'Gum');
    });

    testWidgets('if the existing-item check fails, Save does not write', (
      tester,
    ) async {
      final repo = FakeItemRepo();
      await pumpScreen(tester, repo);
      await fillForm(
        tester,
      ); // moving between fields already did the blur lookup
      repo.failReads = true;

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save the item. Please try again.'),
        findsOneWidget,
      );
      expect(repo.upserts, 0); // never overwrite blind
    });

    testWidgets('a failed lookup on Done is reported, not swallowed', (
      tester,
    ) async {
      final repo = FakeItemRepo()..failReads = true;
      await pumpScreen(tester, repo);

      await tester.enterText(field('Barcode'), '123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        find.text('Could not look up that barcode. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed delete says so and keeps the item in edit mode', (
      tester,
    ) async {
      final repo = FakeItemRepo()
        ..store['A'] = const Item(
          barcode: 'A',
          name: 'Noodles',
          priceCents: 1500,
        );
      await pumpScreen(tester, repo);
      await tester.enterText(field('Barcode'), 'A');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      repo.failWrites = true;
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete the item. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Edit item'), findsOneWidget);
      expect(repo.store.containsKey('A'), isTrue);
    });
  });
}
