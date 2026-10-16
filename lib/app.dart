import 'package:flutter/material.dart';

import 'features/encode/item_list_screen.dart';
import 'features/home/home_screen.dart';
import 'features/read/read_screen.dart';
import 'features/sell/sell_screen.dart';
import 'features/sync/sync_screen.dart';
import 'shared/empty_state.dart';

/// Shown instead of the app when the database can't be opened at startup.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SukiScan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: Scaffold(
        body: EmptyState(
          icon: Icons.error_outline,
          title: "SukiScan couldn't open your items",
          message:
              'Make sure your phone has free storage space, then try again. '
              'Your items have not been deleted.',
          actionLabel: 'Try again',
          onAction: onRetry,
        ),
      ),
    );
  }
}

class SukiScanApp extends StatelessWidget {
  const SukiScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SukiScan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/encode': (_) => const ItemListScreen(),
        '/read': (_) => const ReadScreen(),
        '/sell': (_) => const SellScreen(),
        '/sync': (_) => const SyncScreen(),
      },
    );
  }
}
