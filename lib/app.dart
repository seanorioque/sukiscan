import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/shell/app_shell.dart';
import 'features/sync/sync_screen.dart';
import 'shared/empty_state.dart';
import 'shared/scanner_view.dart';

/// Shown instead of the app when the database can't be opened at startup.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SukiScan',
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
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
  /// [scannerBuilder] replaces the camera on Read and Sell (for tests).
  const SukiScanApp({super.key, this.scannerBuilder});

  final ScannerBuilder? scannerBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SukiScan',
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      initialRoute: '/',
      routes: {
        '/': (_) => AppShell(scannerBuilder: scannerBuilder),
        '/sync': (_) => const SyncScreen(),
      },
    );
  }
}
