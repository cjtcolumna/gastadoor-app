import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/pill_height.dart';
import '../domain/account.dart';
import '../domain/account_groups.dart';
import 'account_avatar.dart';
import 'account_type_ui.dart';

/// Picks one account (or sub-account) for a transaction.
///
/// - An account with sub-accounts gets its own heading and line: its pill
///   (with the icon) followed by one text-only pill per sub-account.
/// - Accounts with no sub-accounts come last, together, under an "Other
///   accounts" heading (icon + name).
///
/// There are no boxes: a small grey heading with a thin line groups the
/// pills. The pills look like the category pills, with the balance in small
/// text under each name. The selected pill is filled with a light version of
/// the account's color (GoTyme's teal, GCash's blue...) or the app green.
/// Sub-accounts use their parent's color. Only one pill is selected.
class AccountPickerCards extends StatelessWidget {
  const AccountPickerCards({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
    this.balances,
    this.disabledId,
    this.archivedAccount,
    this.emptyText = 'No accounts yet. Add one in the Accounts tab.',
  });

  /// Every account to show. Sub-accounts are grouped under their parent.
  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<String>? onChanged;

  /// Each account's balance in cents, by id. Shown under the names; while
  /// this is null (still loading) no balances are shown.
  final Map<String, int>? balances;

  /// An account that is shown greyed out and can't be picked (a transfer's
  /// "To" can't be the same as its "From").
  final String? disabledId;

  /// When editing an old transaction from an archived account, that account,
  /// shown as a greyed-out pill so you can see where the money came from.
  final Account? archivedAccount;

  /// What to say when there is nothing to pick.
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final archived = archivedAccount;
    if (accounts.every((a) => a.id == disabledId) && archived == null) {
      return Text(emptyText);
    }

    final groups = groupAccounts(accounts);
    final plain = groups.where((g) => !g.hasChildren).toList();
    final cards = groups.where((g) => g.hasChildren).toList();

    final green = Theme.of(context).colorScheme.primary;

    _AccountPill pill(Account account, {String? label, Widget? avatar}) {
      return _AccountPill(
        label: label ?? accountLabel(account, accounts),
        avatar: avatar,
        balanceCents: balances?[account.id],
        color: _brandColor(account, accounts, green),
        selected: account.id == selectedId,
        onTap: onChanged == null || account.id == disabledId
            ? null
            : () => onChanged!(account.id),
      );
    }

    final sections = <Widget>[
      for (final group in cards)
        _GroupSection(
          title: group.account.name,
          children: [
            pill(
              group.account,
              label: mainPillLabel(group),
              avatar: AccountAvatar(account: group.account, size: 16),
            ),
            // Under its heading the parent is obvious, so just the name.
            for (final child in group.children)
              pill(
                child,
                label: child.name,
                avatar: AccountAvatar(account: child, size: 16),
              ),
          ],
        ),
      // Every account that has no sub-accounts, together, on the last row.
      // It only needs a heading when there are other headings above it.
      if (archived != null || plain.isNotEmpty)
        _GroupSection(
          title: cards.isEmpty ? null : 'Other accounts',
          children: [
            if (archived != null)
              ChoiceChip(
                avatar: Icon(archived.type.icon, size: 18),
                label: Text('${archived.name} (archived)'),
                selected: archived.id == selectedId,
                onSelected: null, // can't pick it for new money, only keep it
              ),
            for (final group in plain)
              pill(
                group.account,
                avatar: AccountAvatar(account: group.account, size: 16),
              ),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          sections[i],
        ],
      ],
    );
  }
}

/// The color for [account]: its bank's color, or [fallback] (the app green).
/// A sub-account uses its parent's bank.
Color _brandColor(Account account, List<Account> all, Color fallback) {
  final main = account.parentId == null
      ? account
      : all.where((a) => a.id == account.parentId).firstOrNull;
  final bank = main == null ? null : bankOf(main);
  return bank == null ? fallback : Color(bank.color);
}

/// A light, calm version of [color] for a selected pill's fill: the same
/// hue, but very light and never neon. Dark text reads well on every one.
Color lightFill(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness(0.88)
      .withSaturation(math.min(hsl.saturation, 0.6))
      .toColor();
}

/// A few pills under a small grey heading like `-- name ------`: a short line,
/// the name, then a thin line that runs to the right edge. No box. With no [title] it is just the pills.
class _GroupSection extends StatelessWidget {
  const _GroupSection({required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          // "-- name ------": a short line, the name, then a line that
          // stretches to the end of the available space.
          LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                SizedBox(
                  width: 14,
                  child: Divider(height: 1, color: context.appColors.border),
                ),
                const SizedBox(width: 8),
                // The name takes only the room it needs (a very long one is
                // cut short), so the line after it gets everything left. A
                // plain Flexible would split the free space 50/50 and leave
                // the line short.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.max(0, constraints.maxWidth * 0.7),
                  ),
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Divider(height: 1, color: context.appColors.border),
                ),
              ],
            ),
          ),
        if (title != null) const SizedBox(height: 8),
        // runSpacing keeps a clear gap when the pills wrap to a next line.
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

/// One choice. Looks like a category pill; when selected it gets a light
/// fill and a thin border in the account's [color]. Under the name, the
/// balance in small text (when [balanceCents] is known).
class _AccountPill extends StatelessWidget {
  const _AccountPill({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.balanceCents,
    this.avatar,
  });

  final String label;
  final int? balanceCents;
  final Color color;
  final bool selected;

  /// Null makes the pill grey and untappable.
  final VoidCallback? onTap;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cents = balanceCents;
    return _RevealWhenSelected(
      selected: selected,
      // A fixed height, so a pill is the same size with or without a balance
      // line (and the same as a category pill).
      child: SizedBox(
        height: pillHeight,
        child: ChoiceChip(
          avatar: avatar,
          // The name, with the balance in small text under it. Long names
          // get "..." instead of overflowing.
          label: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(fontSize: 11),
              ),
              if (cents != null)
                Text(
                  Money.format(cents),
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: cents < 0
                        ? context.appColors.expense
                        : theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          selected: selected,
          showCheckmark: false,
          // Selected: light fill + thin border in the account's color.
          // Unselected: the theme's white fill and border, like category pills.
          selectedColor: lightFill(color),
          side: selected ? BorderSide(color: color) : null,
          // A compact pill: tight padding, and no invisible extra tap area
          // (the gap between rows comes from the Wrap's runSpacing).
          visualDensity: VisualDensity.compact,
          // Room around the text, so it never touches the pill's border.
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: onTap == null ? null : (_) => onTap!(),
        ),
      ),
    );
  }
}

/// Scrolls its child into view when it becomes selected (including when the
/// form first opens), so a pre-selected account lower in the list is seen.
/// It only scrolls if the child is not already fully visible.
class _RevealWhenSelected extends StatefulWidget {
  const _RevealWhenSelected({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  State<_RevealWhenSelected> createState() => _RevealWhenSelectedState();
}

class _RevealWhenSelectedState extends State<_RevealWhenSelected> {
  @override
  void initState() {
    super.initState();
    if (widget.selected) _reveal();
  }

  @override
  void didUpdateWidget(_RevealWhenSelected oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) _reveal();
  }

  void _reveal() {
    // Wait for this frame to be laid out, so the position is known.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
