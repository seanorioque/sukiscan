import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/item_repository.dart';
import '../../domain/item.dart';
import '../../shared/app_feedback.dart';
import '../../shared/scanner_view.dart';

String? _required(String? v, String message) =>
    (v ?? '').trim().isEmpty ? message : null;

String? _validatePrice(String? v) {
  final cents = parseCents(v ?? '');
  if (cents == null) return 'Enter a valid price';
  return cents > 0 ? null : 'Price must be greater than 0';
}

class EncodeScreen extends ConsumerStatefulWidget {
  const EncodeScreen({super.key, this.initialBarcode, this.editItem});

  /// Pre-fills the barcode field (e.g. from Read's "not found" shortcut).
  final String? initialBarcode;

  /// Opens the form already filled with this saved item (from the items list).
  /// The barcode is then fixed, and saving or deleting closes the screen.
  final Item? editItem;

  @override
  ConsumerState<EncodeScreen> createState() => _EncodeScreenState();
}

class _EncodeScreenState extends ConsumerState<EncodeScreen> {
  final _form = GlobalKey<FormState>();
  final _barcode = TextEditingController();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();

  /// Set when the barcode matches a saved item; Save then updates it.
  Item? _editing;

  @override
  void initState() {
    super.initState();
    final item = widget.editItem;
    if (item == null) {
      _barcode.text = widget.initialBarcode ?? '';
    } else {
      _barcode.text = item.barcode;
      _name.text = item.name;
      _price.text = centsToInput(item.priceCents);
      _stock.text = item.stockQty.toString();
      _editing = item;
    }
  }

  /// Items opened from the list close when done; the add form stays open so
  /// several items can be entered in a row.
  void _done() {
    if (widget.editItem != null) {
      Navigator.pop(context);
    } else {
      _clearForm();
    }
  }

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
    if (code == null) return;
    ref.read(feedbackProvider).scan();
    _barcode.text = code;
    await _tryLookup();
  }

  /// [_lookup] for places where nobody else can handle a database failure.
  Future<void> _tryLookup() async {
    try {
      await _lookup();
    } catch (_) {
      if (mounted) {
        ref.read(feedbackProvider).error();
        _snack('Could not look up that barcode. Please try again.');
      }
    }
  }

  /// If the typed/scanned barcode already exists, load it into the form
  /// and switch to edit mode. Returns true when an existing item was loaded.
  Future<bool> _lookup() async {
    final code = _barcode.text.trim();
    if (code.isEmpty || code == _editing?.barcode) return false;
    final item = await ref.read(itemRepositoryProvider).get(code);
    if (!mounted || item == null) return false;
    _name.text = item.name;
    _price.text = centsToInput(item.priceCents);
    _stock.text = item.stockQty.toString();
    setState(() => _editing = item);
    return true;
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      // Barcode typed but never left the field: don't overwrite an existing item blindly.
      // (If this lookup fails we stop: saving without it could overwrite an item.)
      if (_editing == null && await _lookup()) {
        _snack('Item already exists — edit it and save again');
        return;
      }
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
    } catch (_) {
      // The form is left as it was so nothing has to be retyped.
      if (mounted) {
        ref.read(feedbackProvider).error();
        _snack('Could not save the item. Please try again.');
      }
      return;
    }
    if (!mounted) return;
    refreshItems(ref);
    ref.read(feedbackProvider).success();
    _snack('Item saved');
    _done();
  }

  Future<void> _delete() async {
    final item = _editing!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Remove "${item.name}" from your items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(itemRepositoryProvider).softDelete(item.barcode);
    } catch (_) {
      if (mounted) {
        ref.read(feedbackProvider).error();
        _snack('Could not delete the item. Please try again.');
      }
      return;
    }
    if (!mounted) return;
    refreshItems(ref);
    ref.read(feedbackProvider).success();
    _snack('Item deleted');
    _done();
  }

  void _clearForm() {
    _form.currentState!.reset();
    for (final c in [_barcode, _name, _price, _stock]) {
      c.clear();
    }
    setState(() => _editing = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing == null ? 'Encode item' : 'Edit item'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Focus(
              onFocusChange: (focused) {
                if (!focused) _tryLookup();
              },
              child: TextFormField(
                controller: _barcode,
                // From the list the barcode is the item's identity: changing it
                // would quietly create a second item, so it is locked.
                readOnly: widget.editItem != null,
                validator: (v) => _required(v, 'Barcode is required'),
                onChanged: (v) {
                  if (_editing != null && v.trim() != _editing!.barcode) {
                    setState(() => _editing = null);
                  }
                },
                onFieldSubmitted: (_) => _tryLookup(),
                decoration: InputDecoration(
                  labelText: 'Barcode',
                  helperText: widget.editItem != null
                      ? "The barcode can't be changed. To fix it, delete this "
                            'item and add it again.'
                      : null,
                  helperMaxLines: 2,
                  suffixIcon: widget.editItem != null
                      ? null
                      : IconButton(
                          tooltip: 'Scan barcode',
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: _scan,
                        ),
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
            if (_editing != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
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
