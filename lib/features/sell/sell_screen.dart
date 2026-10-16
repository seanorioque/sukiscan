import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/item_repository.dart';
import '../../domain/cart.dart';
import '../../shared/scanner_view.dart';
import 'cart_provider.dart';

const _cooldown = Duration(milliseconds: 1500);

Widget _defaultScanner(void Function(String code) onScan) =>
    ScannerView(onScan: onScan, cooldown: _cooldown, feedback: true);

/// Continuous scanning: every accepted scan adds the item to the cart, or +1.
class SellScreen extends ConsumerWidget {
  /// [scannerBuilder] exists so tests can replace the camera.
  const SellScreen({super.key, this.scannerBuilder = _defaultScanner});

  final ScannerBuilder scannerBuilder;

  Future<void> _onScan(BuildContext context, WidgetRef ref, String code) async {
    final item = await ref.read(itemRepositoryProvider).get(code);
    if (item != null) {
      ref.read(cartProvider.notifier).add(item);
    } else if (context.mounted) {
      // Placeholder until the "unknown barcode → encode it" alert task.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Not found: $code')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          Expanded(
            flex: 2,
            child: scannerBuilder((code) => _onScan(context, ref, code)),
          ),
          Expanded(flex: 3, child: _CartList(cart)),
          _TotalBar(cart.totalCents),
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
  const _TotalBar(this.totalCents);

  final int totalCents;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: Theme.of(context).textTheme.titleLarge),
              Text(
                formatCents(totalCents),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
