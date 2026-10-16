import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/sale_repository.dart';
import 'cart_provider.dart';

/// Bottom sheet: optional cash tendered, change due, and Confirm.
/// Confirm saves the sale in one transaction, then clears the cart.
Future<void> showCheckoutSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true, // lets the sheet rise above the keyboard
      builder: (_) => const CheckoutSheet(),
    );

class CheckoutSheet extends ConsumerStatefulWidget {
  const CheckoutSheet({super.key});

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  final _cash = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  Future<void> _confirm(int? cashCents, int changeCents) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(saleRepositoryProvider)
          .checkout(ref.read(cartProvider), cashCents: cashCents);
    } catch (e) {
      // Nothing was written (single transaction); keep the cart so the user can retry.
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the sale. Please try again.';
        });
      }
      return;
    }
    ref.read(cartProvider.notifier).clear();
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            cashCents == null
                ? 'Sale saved'
                : 'Sale saved — change ${formatCents(changeCents)}',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(
      cartProvider,
    ); // live: the camera may still add items
    final total = cart.totalCents;
    final text = _cash.text.trim();
    final cash = text.isEmpty ? null : parseCents(text);
    final invalid = text.isNotEmpty && cash == null;
    final short = cash != null && cash < total;
    final change = cash == null ? 0 : cash - total;
    final canConfirm = !_saving && !cart.isEmpty && !invalid && !short;
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Total', style: theme.titleMedium),
          Text(formatCents(total), style: theme.displaySmall),
          const SizedBox(height: 16),
          TextField(
            controller: _cash,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Cash tendered (optional)',
              prefixText: '₱ ',
              errorText: invalid ? 'Enter a valid amount' : null,
            ),
          ),
          const SizedBox(height: 12),
          if (short)
            Text(
              'Short by ${formatCents(total - cash)}',
              style: theme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            )
          else if (cash != null)
            Text('Change due ${formatCents(change)}', style: theme.titleLarge),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: canConfirm ? () => _confirm(cash, change) : null,
            child: const Text('Confirm sale'),
          ),
        ],
      ),
    );
  }
}
