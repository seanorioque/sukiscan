import 'package:flutter/material.dart';

import 'receive_screen.dart';
import 'send_screen.dart';

/// Sync menu: send this phone's items to another phone, or receive from one.
class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sync')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              leading: const Icon(Icons.qr_code_2, size: 36),
              title: const Text('Send items'),
              subtitle: const Text('Show QR codes for another phone to scan'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const SendScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              leading: const Icon(Icons.qr_code_scanner, size: 36),
              title: const Text('Receive items'),
              subtitle: const Text('Scan the QR codes on another phone'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const ReceiveScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
