import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/sync_repository.dart';
import '../../domain/sync_codec.dart';
import '../../shared/empty_state.dart';

/// Shows the catalog as a looping carousel of QR codes for another phone to scan.
class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({
    super.key,
    this.interval = const Duration(milliseconds: 500),
  });

  /// How long each frame stays up while auto-advancing.
  final Duration interval;

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  List<String>? _frames; // null while loading
  int _itemCount = 0;
  Object? _error;
  int _index = 0;
  bool _playing = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await ref.read(syncRepositoryProvider).exportAll();
      if (!mounted) return;
      setState(() {
        _itemCount = items.length;
        _frames = items.isEmpty ? [] : buildFrames(encodeCatalog(items));
      });
      _startTimer();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final frames = _frames;
    if (!_playing || frames == null || frames.length < 2) return;
    _timer = Timer.periodic(
      widget.interval,
      (_) => setState(() => _index = (_index + 1) % frames.length),
    );
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    _startTimer();
  }

  /// Manual paging stops the auto-advance so the frame stays where you put it.
  void _page(int delta) {
    final n = _frames!.length;
    setState(() {
      _index = (_index + delta) % n;
      _playing = false;
    });
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send items')),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        message: 'Could not load your items. Please try again.',
        actionLabel: 'Try again',
        onAction: () {
          setState(() {
            _error = null;
            _frames = null; // back to the loading spinner
          });
          _load();
        },
      );
    }
    final frames = _frames;
    if (frames == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (frames.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'You have no items to send yet. Add some in Encode first.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Sending $_itemCount item${_itemCount == 1 ? '' : 's'}. '
              'Point the other phone at this screen and keep both steady.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, box) => QrImageView(
                    // Keyed by the frame text: a new frame is a fresh QR, and
                    // tests can read which frame is showing.
                    key: ValueKey(frames[_index]),
                    data: frames[_index],
                    size: box.biggest.shortestSide,
                    // QR codes need dark-on-light even in dark mode.
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Frame ${_index + 1} of ${frames.length}',
              style: text.titleMedium,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous frame',
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () => _page(-1),
                ),
                IconButton(
                  tooltip: _playing ? 'Pause' : 'Play',
                  iconSize: 40,
                  icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle),
                  onPressed: frames.length < 2 ? null : _togglePlay,
                ),
                IconButton(
                  tooltip: 'Next frame',
                  icon: const Icon(Icons.skip_next),
                  onPressed: () => _page(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
