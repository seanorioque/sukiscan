import 'package:flutter/material.dart';

import 'features/encode/encode_screen.dart';
import 'features/home/home_screen.dart';
import 'features/read/read_screen.dart';
import 'features/sell/sell_screen.dart';
import 'features/sync/sync_screen.dart';

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
        '/encode': (_) => const EncodeScreen(),
        '/read': (_) => const ReadScreen(),
        '/sell': (_) => const SellScreen(),
        '/sync': (_) => const SyncScreen(),
      },
    );
  }
}
