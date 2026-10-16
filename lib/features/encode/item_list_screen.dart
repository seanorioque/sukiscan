import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/clock.dart';
import '../../core/money.dart';
import '../../data/csv_files.dart';
import '../../data/item_repository.dart';
import '../../domain/item.dart';
import '../../domain/items_csv.dart';
import '../../shared/app_feedback.dart';
import '../../shared/brand_app_bar.dart';
import '../../shared/empty_state.dart';
import '../../shared/ui_helpers.dart';
import 'encode_screen.dart';

/// Encoding tab: every saved item. Tap one to edit it; the button adds a new one.
class ItemListScreen extends ConsumerStatefulWidget {
  const ItemListScreen({super.key});

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  String _query = '';

  void _open(Widget screen) =>
      Navigator.push<void>(context, MaterialPageRoute(builder: (_) => screen));

  /// Reads a CSV file into items. Any bad row fails the whole file, with every
  /// cause listed, and nothing is imported.
  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final feedback = ref.read(feedbackProvider);
    final Uint8List? bytes;
    try {
      bytes = await ref.read(csvFilesProvider).pick();
    } catch (_) {
      feedback.error();
      messenger.showMessage('Could not open that file. Please try again.');
      return;
    }
    if (bytes == null || !mounted) return; // cancelled

    final parsed = parseItemsCsv(bytes);
    if (!parsed.ok) {
      feedback.error();
      await showDialog<void>(
        context: context,
        builder: (_) => _ImportFailedDialog(parsed.problems),
      );
      return;
    }

    try {
      final r = await ref
          .read(itemRepositoryProvider)
          .importItems(parsed.items);
      if (!mounted) return;
      refreshItems(ref);
      feedback.success();
      final n = r.created + r.updated;
      messenger.showMessage(
        'Imported $n item${n == 1 ? '' : 's'}: '
        '${r.created} new, ${r.updated} updated',
      );
    } catch (_) {
      feedback.error();
      messenger.showMessage(
        'Could not save the imported items. Nothing was changed.',
      );
    }
  }

  /// Saves every item as a CSV file the user picks a place for.
  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final feedback = ref.read(feedbackProvider);
    try {
      final items = await ref.read(itemRepositoryProvider).allLive();
      if (!mounted) return;
      if (items.isEmpty) {
        messenger.showMessage('There are no items to export yet.');
        return;
      }
      final day = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.fromMillisecondsSinceEpoch(ref.read(clockProvider)()));
      final saved = await ref
          .read(csvFilesProvider)
          .save(
            'sukiscan-items-$day.csv',
            Uint8List.fromList(utf8.encode(itemsToCsv(items))),
          );
      if (!saved) return; // cancelled
      feedback.success();
      messenger.showMessage(
        'Exported ${items.length} item${items.length == 1 ? '' : 's'}',
      );
    } catch (_) {
      feedback.error();
      messenger.showMessage('Could not export your items. Please try again.');
    }
  }

  bool _matches(Item i) {
    final q = _query.trim().toLowerCase();
    return q.isEmpty ||
        i.name.toLowerCase().contains(q) ||
        i.barcode.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemListProvider);
    final count = items.asData?.value.length;
    return Scaffold(
      appBar: BrandAppBar(
        menuActions: [
          ('Import from CSV', Icons.file_upload_outlined, _import),
          ('Export to CSV', Icons.file_download_outlined, _export),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(const EncodeScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    count == null || count == 0 ? 'Items' : 'Items ($count)',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => EmptyState(
                icon: Icons.error_outline,
                message: 'Could not load your items. Please try again.',
                actionLabel: 'Try again',
                onAction: () => ref.invalidate(itemListProvider),
              ),
              data: (all) => all.isEmpty ? _empty() : _list(all),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => EmptyState(
    icon: Icons.inventory_2_outlined,
    title: 'No items yet',
    message: 'Add your first item to start selling.',
    actionLabel: 'Add item',
    onAction: () => _open(const EncodeScreen()),
  );

  Widget _list(List<Item> all) {
    final shown = all.where(_matches).toList();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search by name or barcode',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  message: 'No items match your search.',
                )
              : ListView.builder(
                  // Room below the last row so the button never covers it.
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: shown.length,
                  itemBuilder: (_, i) {
                    final item = shown[i];
                    return Card(
                      child: ListTile(
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${formatCents(item.priceCents)} · '
                          'Stock: ${item.stockQty} · ${item.barcode}',
                        ),
                        trailing: Icon(
                          Icons.edit_outlined,
                          color: scheme.primary,
                        ),
                        onTap: () => _open(EncodeScreen(editItem: item)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// "Import failed": says nothing was imported and lists the causes.
class _ImportFailedDialog extends StatelessWidget {
  const _ImportFailedDialog(this.problems);

  final List<String> problems;

  /// A file with hundreds of bad rows shouldn't make an endless dialog.
  static const _shown = 8;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
      ),
      title: const Text('Import failed'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nothing was imported. Fix these problems in the file and try '
              'again:',
            ),
            const SizedBox(height: 12),
            for (final p in problems.take(_shown))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $p'),
              ),
            if (problems.length > _shown)
              Text('…and ${problems.length - _shown} more.'),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
