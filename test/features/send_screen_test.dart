import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sukiscan/data/sync_repository.dart';
import 'package:sukiscan/domain/item.dart';
import 'package:sukiscan/domain/sync_codec.dart';
import 'package:sukiscan/features/sync/send_screen.dart';

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

Future<void> pump(WidgetTester tester, FakeSyncRepo repo) => tester.pumpWidget(
  ProviderScope(
    overrides: [syncRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(home: SendScreen()),
  ),
);

String shownData(WidgetTester tester) =>
    (tester.widget<QrImageView>(find.byType(QrImageView)).key!
            as ValueKey<String>)
        .value;

int shownFrame(WidgetTester tester) {
  final m = RegExp(
    r'Frame (\d+) of',
  ).firstMatch(tester.widget<Text>(find.textContaining('Frame ')).data!);
  return int.parse(m!.group(1)!);
}

void main() {
  testWidgets('shows a QR for frame 1 and the frame counter', (tester) async {
    await pump(tester, FakeSyncRepo(catalog(300)));
    await tester.pump();

    final data = shownData(tester);
    expect(SyncFrame.parse(data).index, 0);
    expect(find.textContaining('Sending 300 items'), findsOneWidget);
    final total = SyncFrame.parse(data).total;
    expect(total, greaterThan(1));
    expect(find.text('Frame 1 of $total'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // stop the timer
  });

  testWidgets('auto-advances every 500 ms and wraps around', (tester) async {
    await pump(tester, FakeSyncRepo(catalog(300)));
    await tester.pump();
    final total = SyncFrame.parse(shownData(tester)).total;

    await tester.pump(const Duration(milliseconds: 500));
    expect(shownFrame(tester), 2);
    expect(SyncFrame.parse(shownData(tester)).index, 1);

    await tester.pump(const Duration(milliseconds: 400));
    expect(shownFrame(tester), 2); // not yet

    await tester.pump(const Duration(milliseconds: 100));
    expect(shownFrame(tester), 3);

    for (var i = 3; i < total; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(shownFrame(tester), total);
    await tester.pump(const Duration(milliseconds: 500));
    expect(shownFrame(tester), 1); // wrapped
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'every frame shown belongs to one session and rebuilds the catalog',
    (tester) async {
      final items = catalog(120);
      await pump(tester, FakeSyncRepo(items));
      await tester.pump();
      final total = SyncFrame.parse(shownData(tester)).total;

      final r = SyncReassembler();
      for (var i = 0; i < total; i++) {
        r.add(shownData(tester));
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(r.isComplete, isTrue);
      expect(r.decode().map((i) => i.toMap()), items.map((i) => i.toMap()));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('manual paging steps frames and stops auto-advance', (
    tester,
  ) async {
    await pump(tester, FakeSyncRepo(catalog(300)));
    await tester.pump();
    final total = SyncFrame.parse(shownData(tester)).total;

    await tester.tap(find.byTooltip('Next frame'));
    await tester.pump();
    expect(shownFrame(tester), 2);

    await tester.pump(const Duration(seconds: 3)); // paused: stays put
    expect(shownFrame(tester), 2);
    expect(find.byTooltip('Play'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous frame'));
    await tester.pump();
    expect(shownFrame(tester), 1);

    await tester.tap(find.byTooltip('Previous frame')); // wraps to the end
    await tester.pump();
    expect(shownFrame(tester), total);

    await tester.tap(find.byTooltip('Next frame')); // wraps to the start
    await tester.pump();
    expect(shownFrame(tester), 1);
  });

  testWidgets('play resumes auto-advance; pause freezes it', (tester) async {
    await pump(tester, FakeSyncRepo(catalog(300)));
    await tester.pump();

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(shownFrame(tester), 1);

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(shownFrame(tester), 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a small catalog is a single static frame', (tester) async {
    await pump(tester, FakeSyncRepo(catalog(1)));
    await tester.pump();

    expect(find.text('Frame 1 of 1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Frame 1 of 1'), findsOneWidget);
    expect(find.textContaining('Sending 1 item.'), findsOneWidget);
  });

  testWidgets('no items shows a message instead of a QR', (tester) async {
    await pump(tester, FakeSyncRepo([]));
    await tester.pump();

    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('no items to send'), findsOneWidget);
  });

  testWidgets('a load failure shows an error', (tester) async {
    await pump(tester, FakeSyncRepo([])..failExport = true);
    await tester.pump();

    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Could not load your items.'), findsOneWidget);
  });
}
