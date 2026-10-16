import 'package:flutter/material.dart';

/// The app name as a small wordmark: a gradient scanner badge + "Suki" in a
/// light weight and "Scan" in heavy accent colour.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'SukiScan',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.tertiary],
              ),
            ),
            child: Icon(
              Icons.qr_code_scanner,
              color: scheme.onPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Suki',
                  style: TextStyle(fontWeight: FontWeight.w400),
                ),
                TextSpan(
                  text: 'Scan',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 22, letterSpacing: -0.8),
          ),
        ],
      ),
    );
  }
}

/// Top bar for the main tabs: the wordmark on the left, the tab's own actions,
/// then a Sync button on the far right.
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandAppBar({super.key, this.actions = const []});

  /// Tab-specific buttons, shown just left of the Sync button.
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 16,
      title: const BrandLogo(key: Key('brand-logo')),
      actions: [
        ...actions,
        IconButton(
          tooltip: 'Sync with another phone',
          icon: const Icon(Icons.sync_alt),
          onPressed: () => Navigator.pushNamed(context, '/sync'),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
