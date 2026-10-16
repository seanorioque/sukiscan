import 'package:sukiscan/data/sync_repository.dart';
import 'package:sukiscan/domain/item.dart';

/// In-memory SyncRepository for widget tests: records calls, can be made to fail.
class FakeSyncRepo implements SyncRepository {
  FakeSyncRepo([this.items = const []]);

  /// What exportAll returns (the sender side).
  final List<Item> items;

  /// What preview and merge report (the receiver side).
  MergeSummary summary = const MergeSummary(created: 1);

  bool failExport = false;
  bool failMerge = false;
  final previewed = <List<Item>>[];
  final merged = <List<Item>>[];

  @override
  Future<List<Item>> exportAll() async {
    if (failExport) throw StateError('db down');
    return items;
  }

  @override
  Future<MergeSummary> preview(List<Item> incoming) async {
    previewed.add(incoming);
    return summary;
  }

  @override
  Future<MergeSummary> merge(List<Item> incoming) async {
    if (failMerge) throw StateError('db down');
    merged.add(incoming);
    return summary;
  }
}
