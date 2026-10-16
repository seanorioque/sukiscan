import 'package:flutter/material.dart';

import '../../data/sync_repository.dart';

/// "X new, Y updated, Z deleted" shown before the user confirms a merge.
class MergePreview extends StatelessWidget {
  const MergePreview(this.summary, {super.key});

  final MergeSummary summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Count(summary.created, 'new'),
            _Count(summary.updated, 'updated'),
            _Count(summary.deleted, 'deleted'),
          ],
        ),
        const SizedBox(height: 12),
        if (summary.changes == 0)
          Text(
            'Nothing to import: your items are already up to date.',
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          )
        else if (summary.unchanged > 0)
          Text(
            '${summary.unchanged} other item${summary.unchanged == 1 ? '' : 's'} '
            'in this transfer will be skipped (yours are newer or identical).',
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.count, this.label);

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$count $label',
      excludeSemantics: true,
      child: Column(
        children: [
          Text('$count', style: text.displaySmall),
          Text(label, style: text.titleMedium),
        ],
      ),
    );
  }
}
