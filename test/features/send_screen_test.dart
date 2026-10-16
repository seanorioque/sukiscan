import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sukiscan/data/sync_repository.dart';
import 'package:sukiscan/domain/sync_codec.dart';
import 'package:sukiscan/features/sync/send_screen.dart';

import '../helpers/catalog.dart';
import '../helpers/fake_sync_repo.dart';

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
    expect(
      find.text('Could not load your items. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('Try again reloads after a load failure', (tester) async {
    final repo = FakeSyncRepo(catalog(5))..failExport = true;
    await pump(tester, repo);
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);

    repo.failExport = false;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
