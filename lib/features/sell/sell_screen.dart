import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/item_repository.dart';
import '../../domain/item.dart';
import '../../domain/cart.dart';
import '../../shared/app_feedback.dart';
import '../../shared/brand_app_bar.dart';
import '../../shared/camera_card.dart';
import '../../shared/empty_state.dart';
import '../../shared/scanner_view.dart';
import '../../shared/ui_helpers.dart';
import '../encode/encode_screen.dart';
import 'cart_provider.dart';
import 'checkout_sheet.dart';

const _cooldown = Duration(milliseconds: 1500);

Widget _defaultScanner(void Function(String code) onScan) =>
    ScannerView(onScan: onScan, cooldown: _cooldown);

/// Continuous scanning: every accepted scan adds the item to the cart, or +1.
class SellScreen extends ConsumerStatefulWidget {
  /// [scannerBuilder] exists so tests can replace the camera.
  const SellScreen({super.key, this.scannerBuilder = _defaultScanner});

  final ScannerBuilder scannerBuilder;

  @override
  ConsumerState<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends ConsumerState<SellScreen> {
  /// True while the "not found" alert (or the Encode screen it opens) is up.
  /// The camera keeps running underneath, so scans are ignored meanwhile
  /// instead of stacking more alerts or touching the cart.
  bool _busy = false;

  /// For damaged labels: type the barcode instead of scanning it. Goes through
  /// the same path as a scan (add / +1, or the "not found" alert).
  Future<void> _enterManually() async {
    if (_busy) return;
    _busy = true; // the camera must not add items behind the dialog
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualEntryDialog(),
    );
    _busy = false;
    if (code != null && mounted) await _onScan(code);
  }

  Future<void> _onScan(String code) async {
    if (_busy) return;
    final Item? item;
    try {
      item = await ref.read(itemRepositoryProvider).get(code);
    } catch (_) {
      // Nothing was added; the cooldown lets the same label be scanned again.
      if (mounted) {
        ref.read(feedbackProvider).error();
        ScaffoldMessenger.of(
          context,
        ).showMessage('Could not look up that item. Please try again.');
      }
      return;
    }
    if (!mounted || _busy) return;
    if (item != null) {
      ref.read(cartProvider.notifier).add(item);
      ref.read(feedbackProvider).scan();
      return;
    }
    ref.read(feedbackProvider).error();
    _busy = true;
    try {
      final encode = await confirm(
        context,
        title: 'Item not found',
        message: 'No item has barcode $code. Encode it now?',
        yesLabel: 'Encode item',
      );
      if (encode && mounted) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => EncodeScreen(initialBarcode: code)),
        );
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: BrandAppBar(
        actions: [
          IconButton(
            tooltip: 'Type barcode',
            icon: const Icon(Icons.keyboard_outlined),
            onPressed: _enterManually,
          ),
          if (!cart.isEmpty)
            IconButton(
              tooltip: 'Clear cart',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: CameraCard(child: widget.scannerBuilder(_onScan)),
          ),
          Expanded(flex: 3, child: _CartList(cart)),
          _TotalBar(cart),
        ],
      ),
    );
  }
}

class _ManualEntryDialog extends StatefulWidget {
  const _ManualEntryDialog();

  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a barcode');
      return;
    }
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Type barcode'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        // Not numbers-only: Code 128 / Code 39 labels can contain letters.
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        decoration: InputDecoration(labelText: 'Barcode', errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

class _CartList extends ConsumerWidget {
  const _CartList(this.cart);

  final Cart cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cart.isEmpty) {
      // While the count loads (or fails) assume items exist: no flash of the hint.
      final noItems = ref.watch(itemCountProvider).asData?.value == 0;
      return noItems
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No items yet',
              message:
                  'Add your items in Encode first, then scan them here to sell.',
              actionLabel: 'Encode an item',
              onAction: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const EncodeScreen()),
              ),
            )
          : const EmptyState(
              icon: Icons.shopping_cart_outlined,
              message: 'Scan items to add them to the sale',
            );
    }
    final notifier = ref.read(cartProvider.notifier);
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        for (final l in cart.lines)
          Card(
            child: ListTile(
              title: Text(
                l.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${formatCents(l.unitPriceCents)} each · ${formatCents(l.totalCents)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Decrease',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => notifier.decrement(l.barcode),
                  ),
                  Text(
                    '${l.qty}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Increase',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => notifier.increment(l.barcode),
                  ),
                  IconButton(
                    tooltip: 'Remove line',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => notifier.remove(l.barcode),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
  final ok = await confirm(
    context,
    title: 'Clear cart?',
    message: 'Remove all items from this sale?',
    yesLabel: 'Clear',
  );
  if (ok) ref.read(cartProvider.notifier).clear();
}

class _TotalBar extends StatelessWidget {
  const _TotalBar(this.cart);

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: text.titleLarge),
                Text(
                  formatCents(cart.totalCents),
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: cart.isEmpty ? null : () => showCheckoutSheet(context),
              child: const Text('Checkout'),
            ),
          ],
        ),
      ),
    );
  }
}
