import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/item_repository.dart';
import '../../domain/item.dart';
import '../../shared/scanner_view.dart';

typedef ScannerBuilder = Widget Function(void Function(String code) onScan);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Read item')),
      body: Column(
        children: [
          Expanded(flex: 3, child: widget.scannerBuilder(_onScan)),
          Expanded(
            flex: 2,
            child: _Result(code: _code, item: _item),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.code, required this.item});

  final String? code;
  final Item? item;

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
