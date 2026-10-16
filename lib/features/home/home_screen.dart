import 'package:flutter/material.dart';

const _menu = [
  (label: 'Encode', icon: Icons.edit_note, route: '/encode'),
  (label: 'Read', icon: Icons.qr_code_scanner, route: '/read'),
  (label: 'Sell', icon: Icons.point_of_sale, route: '/sell'),
  (label: 'Sync', icon: Icons.sync, route: '/sync'),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SukiScan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final m in _menu)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                leading: Icon(m.icon, size: 36),
                title: Text(
                  m.label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, m.route),
              ),
            ),
        ],
      ),
    );
  }
}
