import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/item_repository.dart';
import '../../domain/item.dart';
import '../../shared/empty_state.dart';
import 'encode_screen.dart';

/// Every saved item. Tap one to edit it; the button adds a new one.
class ItemListScreen extends ConsumerStatefulWidget {
  const ItemListScreen({super.key});

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  String _query = '';

  void _open(Widget screen) =>
      Navigator.push<void>(context, MaterialPageRoute(builder: (_) => screen));

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
      appBar: AppBar(
        title: Text(count == null || count == 0 ? 'Items' : 'Items ($count)'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(const EncodeScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Could not load your items. Please try again.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(itemListProvider),
        ),
        data: (all) => all.isEmpty ? _empty() : _list(all),
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
              : ListView.separated(
                  // Room below the last row so the button never covers it.
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = shown[i];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        '${formatCents(item.priceCents)} · '
                        'Stock: ${item.stockQty} · ${item.barcode}',
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _open(EncodeScreen(editItem: item)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
