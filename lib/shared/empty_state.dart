import 'package:flutter/material.dart';

/// Centered icon + message (+ optional button) for screens with nothing to show yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Smaller icon and spacing, for tight spots like a result card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final gap = compact ? 6.0 : 12.0;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 12 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 32 : 48, color: color),
            SizedBox(height: gap),
            if (title != null) ...[
              Text(
                title!,
                style: text.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message,
              style: text.bodyMedium?.copyWith(color: color),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              SizedBox(height: compact ? 10 : 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
