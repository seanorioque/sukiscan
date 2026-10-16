import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/data/sync_repository.dart';
import 'package:sukiscan/features/sync/merge_preview.dart';

Future<void> show(WidgetTester tester, MergeSummary s) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: MergePreview(s))),
  ),
);

void main() {
  testWidgets('shows new, updated and deleted counts', (tester) async {
    await show(tester, const MergeSummary(created: 12, updated: 3, deleted: 1));

    expect(find.text('12'), findsOneWidget);
    expect(find.text('new'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('updated'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('deleted'), findsOneWidget);
    expect(find.textContaining('up to date'), findsNothing);
  });

  testWidgets('zero counts still show, with an up-to-date message', (
    tester,
  ) async {
    await show(tester, const MergeSummary(unchanged: 40));

    expect(find.text('0'), findsNWidgets(3));
    expect(
      find.text('Nothing to import: your items are already up to date.'),
      findsOneWidget,
    );
    expect(find.textContaining('skipped'), findsNothing);
  });

  testWidgets('explains skipped items when there are also changes', (
    tester,
  ) async {
    await show(tester, const MergeSummary(created: 2, unchanged: 5));
    expect(
      find.text(
        '5 other items in this transfer will be skipped (yours are newer or identical).',
      ),
      findsOneWidget,
    );
  });

  testWidgets('singular wording for one skipped item', (tester) async {
    await show(tester, const MergeSummary(updated: 1, unchanged: 1));
    expect(
      find.textContaining('1 other item in this transfer'),
      findsOneWidget,
    );
  });
}
