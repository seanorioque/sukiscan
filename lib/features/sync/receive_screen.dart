import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync_repository.dart';
import '../../domain/item.dart';
import '../../domain/sync_codec.dart';
import '../../shared/scanner_view.dart';
import 'merge_preview.dart';

Widget _defaultScanner(void Function(String code) onScan) =>
    ScannerView(formats: qrFormats, onScan: onScan);

enum _Phase { scanning, working, preview, error }

/// Scan the other phone's QR carousel, check the transfer, show what would
/// change, and merge only after the user confirms. Nothing is written before that.
class ReceiveScreen extends ConsumerStatefulWidget {
  /// [scannerBuilder] exists so tests can replace the camera.
  const ReceiveScreen({super.key, this.scannerBuilder = _defaultScanner});

  final ScannerBuilder scannerBuilder;

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  var _frames = SyncReassembler();
  var _phase = _Phase.scanning;
  String? _note; // scanning hint, e.g. "different transfer"
  String? _error; // why the transfer was rejected, or why saving failed
  List<Item> _items = const [];
  MergeSummary? _summary;
  bool _saving = false;

  /// Throw away everything received so far and start over.
  void _restart() => setState(() {
    _frames = SyncReassembler();
    _phase = _Phase.scanning;
    _note = null;
    _error = null;
    _items = const [];
    _summary = null;
    _saving = false;
  });

  Future<void> _onScan(String code) async {
    if (_phase != _Phase.scanning) return;
    final result = _frames.add(code);
    setState(() {
      _note = switch (result) {
        FrameResult.accepted || FrameResult.duplicate => null,
        FrameResult.otherSession =>
          'That code is from a different transfer, so it was ignored.',
        FrameResult.invalid => 'That QR code is not from SukiScan.',
      };
    });
    if (_frames.isComplete) await _finish();
  }

  /// All frames are in: verify, decode and work out what a merge would do.
  Future<void> _finish() async {
    setState(() => _phase = _Phase.working); // stops further scans immediately
    try {
      final items = _frames.decode();
      final summary = await ref.read(syncRepositoryProvider).preview(items);
      if (!mounted) return;
      setState(() {
        _items = items;
        _summary = summary;
        _phase = _Phase.preview;
      });
    } on SyncChecksumException {
      _fail(
        'The transfer was damaged: a QR code was probably misread. '
        'Nothing was saved. Scan again and keep both phones steady.',
      );
    } on FormatException {
      _fail(
        'Those codes are not a valid SukiScan item list. Nothing was saved.',
      );
    } catch (_) {
      _fail('Something went wrong reading the transfer. Nothing was saved.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _phase = _Phase.error;
    });
  }

  Future<void> _confirm() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    final MergeSummary done;
    try {
      done = await ref.read(syncRepositoryProvider).merge(_items);
    } catch (_) {
      // One transaction: nothing was changed. Stay on the preview to retry.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save the items. Nothing was changed. Try again.';
      });
      return;
    }
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Imported: ${done.created} new, ${done.updated} updated, '
            '${done.deleted} deleted',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive items')),
      body: switch (_phase) {
        _Phase.scanning => _scanning(context),
        _Phase.working => const Center(child: CircularProgressIndicator()),
        _Phase.preview => _preview(context),
        _Phase.error => _errorView(context),
      },
    );
  }

  Widget _scanning(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = _frames.total;
    return Column(
      children: [
        Expanded(flex: 3, child: widget.scannerBuilder(_onScan)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                total == null
                    ? 'Point the camera at the QR code on the other phone'
                    : 'Received ${_frames.received} of $total',
                style: text.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: total == null ? 0 : _frames.received / total,
              ),
              if (_note != null) ...[
                const SizedBox(height: 12),
                Text(
                  _note!,
                  style: text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _preview(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final summary = _summary!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Transfer received',
              style: text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Nothing is saved until you confirm.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            const SizedBox(height: 24),
            MergePreview(summary),
            const Spacer(),
            if (_error != null) ...[
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _saving || summary.changes == 0 ? null : _confirm,
              child: const Text('Confirm and import'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : _restart,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(_error ?? '', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _restart, child: const Text('Scan again')),
          ],
        ),
      ),
    );
  }
}
