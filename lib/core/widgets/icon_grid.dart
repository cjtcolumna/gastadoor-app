import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// Every icon from [appIcons], as tappable circles. The picked one gets a
/// soft fill and a ring in [color]. Categories and sub-accounts both use it.
class IconGrid extends StatelessWidget {
  const IconGrid({
    super.key,
    required this.selected,
    required this.color,
    required this.onChanged,
  });

  /// The saved name of the picked icon.
  final String selected;

  /// The color of the picked icon's fill and ring.
  final Color color;

  /// Null turns the grid off (e.g. while saving).
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final MapEntry(key: name, value: icon) in appIcons.entries)
          Semantics(
            label: name,
            selected: name == selected,
            button: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onChanged == null ? null : () => onChanged!(name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: name == selected
                      ? color.withValues(alpha: 0.16)
                      : Colors.transparent,
                  border: Border.all(
                    color: name == selected ? color : context.appColors.border,
                    width: name == selected ? 2 : 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: name == selected
                      ? color
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
