import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/scanner_view.dart';
import '../encode/item_list_screen.dart';
import '../read/read_screen.dart';
import '../sell/cart_provider.dart';
import '../sell/sell_screen.dart';

enum AppTab { encode, read, sell }

/// The main screen: three modes behind a bottom navigation bar. Only the
/// selected tab is built, so at most one camera is ever running.
class AppShell extends ConsumerStatefulWidget {
  /// [scannerBuilder] replaces the camera on Read and Sell (for tests).
  const AppShell({super.key, this.scannerBuilder});

  final ScannerBuilder? scannerBuilder;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // Selling is the everyday job, so the app opens on Sell.
  int _index = AppTab.sell.index;

  Widget _tab() {
    final scanner = widget.scannerBuilder;
    return switch (AppTab.values[_index]) {
      AppTab.encode => const ItemListScreen(),
      AppTab.read =>
        scanner == null
            ? const ReadScreen()
            : ReadScreen(scannerBuilder: scanner),
      AppTab.sell =>
        scanner == null
            ? const SellScreen()
            : SellScreen(scannerBuilder: scanner),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cartLines = ref.watch(cartProvider).lines.length;
    return Scaffold(
      body: _tab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Add Items',
          ),
          const NavigationDestination(
            icon: Icon(Icons.sell_outlined),
            selectedIcon: Icon(Icons.sell),
            label: 'Check Price',
          ),
          NavigationDestination(
            // A badge shows how many different items are in the cart.
            icon: Badge(
              isLabelVisible: cartLines > 0,
              label: Text('$cartLines'),
              child: const Icon(Icons.point_of_sale_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: cartLines > 0,
              label: Text('$cartLines'),
              child: const Icon(Icons.point_of_sale),
            ),
            label: 'Sell',
          ),
        ],
      ),
    );
  }
}
