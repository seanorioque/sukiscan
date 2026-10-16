import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/item_repository.dart';
import '../../domain/item.dart';
import '../../shared/scanner_view.dart';
import '../encode/encode_screen.dart';

Widget _defaultScanner(void Function(String code) onScan) =>
    ScannerView(onScan: onScan);

/// Scan a barcode and show the saved item's name, price and stock.
class ReadScreen extends ConsumerStatefulWidget {
  /// [scannerBuilder] exists so tests can replace the camera.
  const ReadScreen({super.key, this.scannerBuilder = _defaultScanner});

  final ScannerBuilder scannerBuilder;

  @override
  ConsumerState<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends ConsumerState<ReadScreen> {
  String? _code; // last scanned barcode
  Item? _item; // null + _code set = not found

  Future<void> _onScan(String code) async {
    if (code == _code) return; // the camera reports the same code every frame
    _code = code;
    final item = await ref.read(itemRepositoryProvider).get(code);
    if (!mounted || code != _code) return; // a newer scan won the race
    setState(() => _item = item);
  }

  Future<void> _encode(String code) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => EncodeScreen(initialBarcode: code),
      ),
    );
    // The item may exist now; forget the last scan so rescanning looks it up again.
    if (!mounted) return;
    setState(() {
      _code = null;
      _item = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Read item')),
      body: Column(
        children: [
          Expanded(flex: 3, child: widget.scannerBuilder(_onScan)),
          Expanded(
            flex: 2,
            child: _Result(code: _code, item: _item, onEncode: _encode),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.code,
    required this.item,
    required this.onEncode,
  });

  final String? code;
  final Item? item;
  final void Function(String code) onEncode;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final Widget body;
    if (code == null) {
      body = const Text('Point the camera at a barcode');
    } else if (item == null) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Not found', style: text.headlineSmall),
          const SizedBox(height: 4),
          Text(code!),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => onEncode(code!),
            child: const Text('Not found — encode this item?'),
          ),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item!.name,
            style: text.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(formatCents(item!.priceCents), style: text.displaySmall),
          const SizedBox(height: 8),
          Text('Stock: ${item!.stockQty}', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(item!.barcode, style: text.bodySmall),
        ],
      );
    }
    return Center(
      child: Padding(padding: const EdgeInsets.all(16), child: body),
    );
  }
}
