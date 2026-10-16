import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/data/sync_repository.dart';
import 'package:sukiscan/domain/item.dart';
import 'package:sukiscan/domain/sync_codec.dart';
import 'package:sukiscan/features/sync/receive_screen.dart';

import '../helpers/fake_sync_repo.dart';

List<Item> catalog(int n) => [
  for (var i = 0; i < n; i++)
    Item(
      barcode: '4800${(i * 7919 % 100000000).toString().padLeft(9, '0')}',
      name: 'Item ${i * 31 % 977} brand ${i % 53}',
      priceCents: 1000 + (i * 37 % 9000),
      stockQty: i % 30,
      updatedAt: 1760600000000 + i * 1234567,
    ),
];

void main() {
  late FakeSyncRepo repo;
  late void Function(String) scan;
  final items = catalog(150);
  final frames = buildFrames(encodeCatalog(items), sessionId: 'aaa');

  Future<void> open(WidgetTester tester) async {
    repo = FakeSyncRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [syncRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  child: const Text('open'),
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReceiveScreen(
                        scannerBuilder: (onScan) {
                          scan = onScan;
                          return const SizedBox.expand();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> scanAll(WidgetTester tester, [List<String>? these]) async {
    for (final f in these ?? frames) {
      scan(f);
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  String corrupt(String frame) {
    final i = frame.length - 3;
    return frame.substring(0, i) +
        (frame[i] == 'A' ? 'B' : 'A') +
        frame.substring(i + 1);
  }

  testWidgets('starts by asking for the first QR code', (tester) async {
    await open(tester);
    expect(
      find.text('Point the camera at the QR code on the other phone'),
      findsOneWidget,
    );
    expect(frames.length, greaterThan(2));
  });

  testWidgets('shows progress n of total, ignoring duplicates', (tester) async {
    await open(tester);
    final total = frames.length;

    scan(frames[3]); // any frame can be first
    await tester.pump();
    expect(find.text('Received 1 of $total'), findsOneWidget);

    scan(frames[3]);
    scan(frames[3]);
    await tester.pump();
    expect(find.text('Received 1 of $total'), findsOneWidget);

    scan(frames[0]);
    await tester.pump();
    expect(find.text('Received 2 of $total'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      2 / total,
    );
  });

  testWidgets('hints on other transfers and non-SukiScan codes, keeps going', (
    tester,
  ) async {
    await open(tester);
    scan(frames[0]);
    await tester.pump();

    scan(buildFrames('QUJDRA==', sessionId: 'zzz').single);
    await tester.pump();
    expect(find.textContaining('different transfer'), findsOneWidget);
    expect(find.text('Received 1 of ${frames.length}'), findsOneWidget);

    scan('https://example.com');
    await tester.pump();
    expect(find.textContaining('not from SukiScan'), findsOneWidget);

    scan(frames[1]); // a good frame clears the hint
    await tester.pump();
    expect(find.textContaining('not from SukiScan'), findsNothing);
    expect(find.text('Received 2 of ${frames.length}'), findsOneWidget);
  });

  testWidgets('a complete transfer shows the preview; nothing is merged yet', (
    tester,
  ) async {
    await open(tester);
    repo.summary = const MergeSummary(
      created: 140,
      updated: 6,
      deleted: 2,
      unchanged: 2,
    );
    await scanAll(tester, frames.reversed.toList()); // out of order

    expect(find.text('Transfer received'), findsOneWidget);
    expect(find.text('140'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(repo.previewed, hasLength(1));
    expect(
      repo.previewed.single.map((i) => i.toMap()),
      items.map((i) => i.toMap()),
    );
    expect(repo.merged, isEmpty);
  });

  testWidgets('confirm merges the items, then returns with a summary', (
    tester,
  ) async {
    await open(tester);
    repo.summary = const MergeSummary(created: 140, updated: 6, deleted: 2);
    await scanAll(tester);

    await tester.tap(find.text('Confirm and import'));
    await tester.pumpAndSettle();

    expect(repo.merged, hasLength(1));
    expect(repo.merged.single, hasLength(items.length));
    expect(find.text('Receive items'), findsNothing); // popped back
    expect(find.text('open'), findsOneWidget);
    expect(
      find.text('Imported: 140 new, 6 updated, 2 deleted'),
      findsOneWidget,
    );
  });

  testWidgets('cancel at the preview writes nothing and starts over', (
    tester,
  ) async {
    await open(tester);
    await scanAll(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.merged, isEmpty);
    expect(
      find.text('Point the camera at the QR code on the other phone'),
      findsOneWidget,
    ); // fresh: earlier frames forgotten
  });

  testWidgets('a misread frame rejects the whole transfer', (tester) async {
    await open(tester);
    final bad = [...frames]..[1] = corrupt(frames[1]);
    await scanAll(tester, bad);

    expect(find.textContaining('transfer was damaged'), findsOneWidget);
    expect(find.text('Transfer received'), findsNothing);
    expect(repo.previewed, isEmpty);
    expect(repo.merged, isEmpty);

    await tester.tap(find.text('Scan again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Point the camera'), findsOneWidget);

    // A second attempt with clean frames works.
    await scanAll(tester);
    expect(find.text('Transfer received'), findsOneWidget);
  });

  testWidgets('intact data that is not an item list is rejected', (
    tester,
  ) async {
    await open(tester);
    await scanAll(tester, buildFrames('QUJDRA==', sessionId: 'xyz'));

    expect(
      find.textContaining('not a valid SukiScan item list'),
      findsOneWidget,
    );
    expect(repo.merged, isEmpty);
  });

  testWidgets('a failed save keeps the preview so it can be retried', (
    tester,
  ) async {
    await open(tester);
    await scanAll(tester);
    repo.failMerge = true;

    await tester.tap(find.text('Confirm and import'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing was changed'), findsOneWidget);
    expect(find.text('Transfer received'), findsOneWidget);

    repo.failMerge = false;
    await tester.tap(find.text('Confirm and import'));
    await tester.pumpAndSettle();
    expect(repo.merged, hasLength(1));
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('nothing to import: confirm is disabled', (tester) async {
    await open(tester);
    repo.summary = const MergeSummary(unchanged: 150);
    await scanAll(tester);

    expect(find.textContaining('already up to date'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm and import'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('scans after completion are ignored', (tester) async {
    await open(tester);
    await scanAll(tester);
    scan(frames[0]);
    scan(buildFrames('QUJD', sessionId: 'new').single);
    await tester.pumpAndSettle();

    expect(find.text('Transfer received'), findsOneWidget);
    expect(repo.previewed, hasLength(1));
  });
}
