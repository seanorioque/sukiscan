import 'package:flutter/material.dart';

import 'features/home/home_screen.dart';

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
        // Placeholders until each module lands (M2 encode, M3 read, M4 sell, M6 sync).
        '/encode': (_) => const _ComingSoon('Encode'),
        '/read': (_) => const _ComingSoon('Read'),
        '/sell': (_) => const _ComingSoon('Sell'),
        '/sync': (_) => const _ComingSoon('Sync'),
      },
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text('Coming soon')),
      );
}
