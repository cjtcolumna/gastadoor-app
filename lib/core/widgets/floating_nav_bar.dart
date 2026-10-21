import 'package:flutter/material.dart';

/// One tab in the floating bar.
class NavTab {
  const NavTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// A rounded "pill" tab bar that floats above the bottom of the screen.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
    this.onAdd,
  });

  final List<NavTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// When set, a round "+" button appears next to the tabs.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Center(
        heightFactor: 1,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [_shadow(colors)],
                  ),
                  child: Row(
                    children: [
                      for (final (i, tab) in tabs.indexed)
                        Expanded(
                          child: _TabButton(
                            tab: tab,
                            selected: i == currentIndex,
                            onTap: () => onTap(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (onAdd != null) ...[
                const SizedBox(width: 12),
                _AddButton(onPressed: onAdd!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

BoxShadow _shadow(ColorScheme colors) => BoxShadow(
  color: colors.shadow.withValues(alpha: 0.15),
  blurRadius: 24,
  offset: const Offset(0, 8),
);

/// The round "+" button for adding an expense.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [_shadow(colors)],
      ),
      child: IconButton.filled(
        tooltip: 'Add expense',
        onPressed: onPressed,
        iconSize: 30,
        style: IconButton.styleFrom(fixedSize: const Size.square(64)),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final NavTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? tab.selectedIcon : tab.icon, color: color),
              const SizedBox(height: 2),
              Text(
                tab.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
