import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/scanner_view.dart';

class EncodeScreen extends StatefulWidget {
  const EncodeScreen({super.key});

  @override
  State<EncodeScreen> createState() => _EncodeScreenState();
}

class _EncodeScreenState extends State<EncodeScreen> {
  final _barcode = TextEditingController();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();

  @override
  void dispose() {
    _barcode.dispose();
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _ScanPage()),
    );
    if (code != null) _barcode.text = code;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Encode item')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _barcode,
            decoration: InputDecoration(
              labelText: 'Barcode',
              suffixIcon: IconButton(
                tooltip: 'Scan barcode',
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _scan,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Item name'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: const InputDecoration(labelText: 'Price', prefixText: '₱ '),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _stock,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Stock quantity (optional)'),
          ),
        ],
      ),
    );
  }
}

/// Full-screen scanner that returns the first scanned code.
class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _done = false; // the scanner fires repeatedly; pop only once

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode')),
      body: ScannerView(
        onScan: (code) {
          if (_done) return;
          _done = true;
          Navigator.pop(context, code);
        },
      ),
    );
  }
}
