import 'package:flutter/material.dart';

/// A camera preview with rounded corners, inset from the screen edges.
class CameraCard extends StatelessWidget {
  const CameraCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}
