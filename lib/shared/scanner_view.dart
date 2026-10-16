import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Camera preview that reports each detected barcode's raw value.
/// Shows a message + Retry button when the camera can't start (e.g. permission denied).
class ScannerView extends StatefulWidget {
  const ScannerView({
    super.key,
    required this.onScan,
    this.formats = retailFormats,
    this.cooldown = Duration.zero,
    this.feedback = false,
  });

  final void Function(String code) onScan;
  final List<BarcodeFormat> formats;

  /// Minimum time before the same barcode is reported again (Sell uses ~1.5 s).
  final Duration cooldown;

  /// Click sound + haptic tick on every scan that is reported.
  final bool feedback;

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
      if (widget.feedback) {
        // ponytail: system click, not a real beep; swap in an audio package/asset if it's too quiet.
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.mediumImpact();
      }
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
          _ScannerError(error: error, onRetry: _controller.start),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error, required this.onRetry});

  final MobileScannerException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(denied ? Icons.no_photography : Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              denied
                  ? 'Camera permission is needed to scan barcodes.\n'
                        'Allow it in the prompt, or in Settings > Apps > SukiScan > Permissions.'
                  : 'The camera could not start.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
