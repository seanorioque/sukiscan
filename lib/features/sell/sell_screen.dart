import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/item_repository.dart';
import '../../domain/cart.dart';
import '../../shared/scanner_view.dart';
import '../encode/encode_screen.dart';
import 'cart_provider.dart';
import 'checkout_sheet.dart';

const _cooldown = Duration(milliseconds: 1500);

Widget _defaultScanner(void Function(String code) onScan) =>
    ScannerView(onScan: onScan, cooldown: _cooldown, feedback: true);

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

  Future<void> _onScan(String code) async {
    if (_busy) return;
    final item = await ref.read(itemRepositoryProvider).get(code);
    if (!mounted || _busy) return;
    if (item != null) {
      ref.read(cartProvider.notifier).add(item);
      return;
    }
    _busy = true;
    try {
      final encode = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Item not found'),
          content: Text('No item has barcode $code. Encode it now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Encode item'),
            ),
          ],
        ),
      );
      if (encode == true && mounted) {
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
      appBar: AppBar(
        title: const Text('Sell'),
        actions: [
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
          Expanded(flex: 2, child: widget.scannerBuilder(_onScan)),
          Expanded(flex: 3, child: _CartList(cart)),
          _TotalBar(cart),
        ],
      ),
    );
  }
}

class _CartList extends ConsumerWidget {
  const _CartList(this.cart);

  final Cart cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cart.isEmpty) {
      return const Center(child: Text('Scan items to add them to the sale'));
    }
    final notifier = ref.read(cartProvider.notifier);
    return ListView(
      children: [
        for (final l in cart.lines)
          ListTile(
            title: Text(l.name),
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
                  style: Theme.of(context).textTheme.titleMedium,
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
      ],
    );
  }
}

Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Clear cart?'),
      content: const Text('Remove all items from this sale?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );
  if (ok == true) ref.read(cartProvider.notifier).clear();
}

class _TotalBar extends StatelessWidget {
  const _TotalBar(this.cart);

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                    style: text.headlineMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: cart.isEmpty
                    ? null
                    : () => showCheckoutSheet(context),
                child: const Text('Checkout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
