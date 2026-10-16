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

/// One entry in the top bar's menu.
class MenuAction {
  const MenuAction(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Top bar for the main tabs: the wordmark on the left, the tab's own actions,
/// then a menu (hamburger) on the far right. The menu always has Sync, plus
/// any [menuActions] the tab adds (e.g. CSV import/export).
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandAppBar({
    super.key,
    this.actions = const [],
    this.menuActions = const [],
  });

  /// Tab-specific buttons, shown just left of the menu.
  final List<Widget> actions;

  /// Tab-specific menu entries, listed after Sync.
  final List<MenuAction> menuActions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final all = [
      MenuAction(
        'Sync with another phone',
        Icons.sync_alt,
        () => Navigator.pushNamed(context, '/sync'),
      ),
      ...menuActions,
    ];
    return AppBar(
      titleSpacing: 16,
      title: const BrandLogo(key: Key('brand-logo')),
      actions: [
        ...actions,
        PopupMenuButton<MenuAction>(
          tooltip: 'Menu',
          icon: const Icon(Icons.menu),
          onSelected: (a) => a.onTap(),
          itemBuilder: (_) => [
            for (final a in all)
              PopupMenuItem(
                value: a,
                child: Row(
                  children: [
                    Icon(a.icon, size: 20),
                    const SizedBox(width: 12),
                    Flexible(child: Text(a.label)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
