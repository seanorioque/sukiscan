import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scan_cooldown.dart';

/// Formats for Encode / Read / Sell (plan §6).
const retailFormats = [
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upcA,
  BarcodeFormat.upcE,
  BarcodeFormat.code128,
  BarcodeFormat.code39,
];

/// Format for Sync receive.
const qrFormats = [BarcodeFormat.qrCode];

/// Lets a screen take its scanner as a parameter so widget tests can replace the camera.
typedef ScannerBuilder = Widget Function(void Function(String code) onScan);

/// Camera preview that reports each detected barcode's raw value.
/// Shows a message + Retry button when the camera can't start (e.g. permission denied).
class ScannerView extends StatefulWidget {
  const ScannerView({
    super.key,
    required this.onScan,
    this.formats = retailFormats,
    this.cooldown = Duration.zero,
  });

  final void Function(String code) onScan;
  final List<BarcodeFormat> formats;

  /// Minimum time before the same barcode is reported again (Sell uses ~1.5 s).
  final Duration cooldown;

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  late final MobileScannerController _controller = MobileScannerController(
    formats: widget.formats,
  );

  late final _cooldown = ScanCooldown(widget.cooldown);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final code = b.rawValue;
      if (code == null || code.isEmpty || !_cooldown.accept(code)) continue;
      widget.onScan(code);
      return; // one accepted scan per frame
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: _onDetect,
      errorBuilder: (context, error) =>
          ScannerErrorView(error: error, onRetry: _controller.start),
    );
  }
}

/// Shown instead of the camera when it can't start: says why and how to fix it.
class ScannerErrorView extends StatelessWidget {
  const ScannerErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final MobileScannerException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final code = error.errorCode;
    final (icon, message) = switch (code) {
      MobileScannerErrorCode.permissionDenied => (
        Icons.no_photography,
        'Camera permission is needed to scan barcodes.\n'
            'Allow it in the prompt, or in Settings > Apps > TindaScan > Permissions.',
      ),
      MobileScannerErrorCode.unsupported => (
        Icons.no_photography,
        "This phone's camera can't be used for scanning. "
            'You can still type barcodes in by hand.',
      ),
      _ => (
        Icons.error_outline,
        'The camera could not start. '
            'Close other apps that may be using it, then try again.',
      ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            // Retrying can't fix a phone that doesn't support scanning.
            if (code != MobileScannerErrorCode.unsupported) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
