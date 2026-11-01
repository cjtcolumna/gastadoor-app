import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/screen_padding.dart';

/// The More tab: a menu of the things you manage. It has no data of its
/// own; each row opens a full screen (with a back arrow to this list).
/// Settings (profile, password, sign out) is the gear icon on Home instead.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: screenPadding(context),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _MoreRow(
                  icon: Icons.savings_rounded,
                  label: 'Budget',
                  subtitle: 'Categories and monthly limits',
                  onTap: () => context.go('/more/budget'),
                ),
                const Divider(height: 1, indent: 56),
                _MoreRow(
                  icon: Icons.handshake_rounded,
                  label: 'Loans',
                  subtitle: 'Money you lent to others',
                  onTap: () => context.go('/more/loans'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
