import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../data/device_auth.dart';
import '../../data/sale_repository.dart';
import '../../domain/sale.dart';
import '../../shared/app_feedback.dart';
import '../../shared/empty_state.dart';
import '../../shared/ui_helpers.dart';

/// Every finished sale, newest first. Deleting (one or many) asks for the
/// phone's own lock first.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  /// Ids ticked for deletion; null = not selecting.
  Set<String>? _selected;

  bool get _selecting => _selected != null;

  void _toggle(String id) => setState(() {
    final s = _selected!;
    s.contains(id) ? s.remove(id) : s.add(id);
  });

  /// Confirm, then check the phone's lock, then delete.
  Future<void> _delete(List<String> ids) async {
    final messenger = ScaffoldMessenger.of(context);
    final feedback = ref.read(feedbackProvider);
    final n = ids.length;
    final what = n == 1 ? 'this purchase' : '$n purchases';
    final yes = await confirm(
      context,
      title: 'Delete $what?',
      message:
          'This removes it from your history for good. Your item stock '
          'is not changed.',
      yesLabel: 'Delete',
    );
    if (!yes || !mounted) return;

    final outcome = await ref
        .read(deviceAuthProvider)
        .verify('Confirm it is you to delete $what');
    if (!mounted) return;
    if (outcome != AuthOutcome.granted) {
      if (outcome != AuthOutcome.cancelled) feedback.error();
      messenger.showMessage(switch (outcome) {
        AuthOutcome.noScreenLock =>
          'Set a screen lock (PIN, pattern or password) on this phone '
              'to delete purchase history.',
        AuthOutcome.failed =>
          'Could not check your phone lock. Nothing was deleted.',
        _ => 'Nothing was deleted.',
      });
      return;
    }

    try {
      await ref.read(saleRepositoryProvider).deleteSales(ids);
      if (!mounted) return;
      ref.invalidate(saleHistoryProvider);
      setState(() => _selected = null);
      feedback.success();
      messenger.showMessage('Deleted $n purchase${n == 1 ? '' : 's'}');
    } catch (_) {
      feedback.error();
      messenger.showMessage('Could not delete. Nothing was changed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(saleHistoryProvider);
    final all = history.asData?.value ?? const <SaleSummary>[];
    final selected = _selected;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selected = null);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _selecting
              ? IconButton(
                  tooltip: 'Cancel selection',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selected = null),
                )
              : null,
          title: Text(
            _selecting ? '${selected!.length} selected' : 'Purchase history',
          ),
          actions: [
            if (_selecting) ...[
              IconButton(
                tooltip: 'Select all',
                icon: const Icon(Icons.select_all),
                onPressed: () =>
                    setState(() => _selected = {for (final s in all) s.id}),
              ),
              IconButton(
                tooltip: 'Delete selected',
                icon: const Icon(Icons.delete_outline),
                onPressed: selected!.isEmpty
                    ? null
                    : () => _delete(selected.toList()),
              ),
            ] else if (all.isNotEmpty)
              IconButton(
                tooltip: 'Select purchases',
                icon: const Icon(Icons.checklist),
                onPressed: () => setState(() => _selected = {}),
              ),
          ],
        ),
        body: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => EmptyState(
            icon: Icons.error_outline,
            message: 'Could not load your purchase history. Please try again.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(saleHistoryProvider),
          ),
          data: (sales) => sales.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No purchases yet',
                  message: 'Finished sales will show up here.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: sales.length,
                  itemBuilder: (_, i) => _SaleCard(
                    sale: sales[i],
                    selecting: _selecting,
                    checked: selected?.contains(sales[i].id) ?? false,
                    onToggle: () => _toggle(sales[i].id),
                    onDelete: () => _delete([sales[i].id]),
                  ),
                ),
        ),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({
    required this.sale,
    required this.selecting,
    required this.checked,
    required this.onToggle,
    required this.onDelete,
  });

  final SaleSummary sale;
  final bool selecting;
  final bool checked;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final when = DateFormat(
      'MMM d, yyyy · h:mm a',
    ).format(DateTime.fromMillisecondsSinceEpoch(sale.createdAt));
    final n = sale.itemCount;
    final title = Text(
      formatCents(sale.totalCents),
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
    );
    final subtitle = Text('$when · $n item${n == 1 ? '' : 's'}');

    if (selecting) {
      return Card(
        child: CheckboxListTile(
          value: checked,
          onChanged: (_) => onToggle(),
          title: title,
          subtitle: subtitle,
        ),
      );
    }
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: title,
        subtitle: subtitle,
        children: [
          _Lines(sale: sale),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The items of one sale, plus cash and change when they were entered.
class _Lines extends ConsumerWidget {
  const _Lines({required this.sale});

  final SaleSummary sale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(saleLinesProvider(sale.id));
    return lines.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Could not load the items of this purchase.'),
      ),
      data: (items) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Column(
          children: [
            for (final l in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text('${l.qty} × ${l.name}')),
                    Text(formatCents(l.totalCents)),
                  ],
                ),
              ),
            if (sale.cashCents != null) ...[
              const Divider(),
              _kv('Cash', formatCents(sale.cashCents!)),
              _kv('Change', formatCents(sale.cashCents! - sale.totalCents)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(k), Text(v)],
    ),
  );
}
