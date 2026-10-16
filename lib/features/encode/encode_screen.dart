import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/item_repository.dart';
import '../../domain/item.dart';
import '../../shared/scanner_view.dart';

String? _required(String? v, String message) =>
    (v ?? '').trim().isEmpty ? message : null;

String? _validatePrice(String? v) {
  final cents = parseCents(v ?? '');
  if (cents == null) return 'Enter a valid price';
  return cents > 0 ? null : 'Price must be greater than 0';
}

class EncodeScreen extends ConsumerStatefulWidget {
  const EncodeScreen({super.key});

  @override
  ConsumerState<EncodeScreen> createState() => _EncodeScreenState();
}

class _EncodeScreenState extends ConsumerState<EncodeScreen> {
  final _form = GlobalKey<FormState>();
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

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await ref
        .read(itemRepositoryProvider)
        .upsert(
          Item(
            barcode: _barcode.text.trim(),
            name: _name.text.trim(),
            priceCents: parseCents(_price.text)!, // checked by _validatePrice
            stockQty: int.tryParse(_stock.text) ?? 0,
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Item saved')));
    _form.currentState!.reset();
    for (final c in [_barcode, _name, _price, _stock]) {
      c.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Encode item')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _barcode,
              validator: (v) => _required(v, 'Barcode is required'),
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
              validator: (v) => _required(v, 'Name is required'),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Item name'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _price,
              validator: _validatePrice,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Price',
                prefixText: '₱ ',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stock,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Stock quantity (optional)',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
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
