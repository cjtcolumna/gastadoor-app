import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_info.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/screen_padding.dart';
import '../../auth/data/auth_repository.dart';
import 'change_password_sheet.dart';

/// Profile, shortcuts, password, app info, and sign out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your data stays safe in your account. Sign in again any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    // The router notices you're signed out and opens the login screen.
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: screenPadding(context),
        children: [
          _ProfileCard(email: user?.email, createdAt: user?.createdAt),
          const _Heading('Manage'),
          _Group(
            children: [
              _Row(
                icon: Icons.category_rounded,
                label: 'Categories',
                onTap: () => context.go('/categories'),
              ),
              _Row(
                icon: Icons.savings_rounded,
                label: 'Budgets',
                onTap: () => context.go('/budgets'),
              ),
              _Row(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Accounts',
                onTap: () => context.go('/accounts'),
              ),
            ],
          ),
          const _Heading('Security'),
          _Group(
            children: [
              _Row(
                icon: Icons.lock_rounded,
                label: 'Change password',
                onTap: () => showChangePasswordSheet(context),
              ),
            ],
          ),
          const _Heading('About'),
          _Group(
            children: [
              _Row(
                icon: Icons.payments_rounded,
                label: 'Currency',
                value: 'Philippine peso (${Money.format(0).substring(0, 1)})',
              ),
              const _Row(
                icon: Icons.info_rounded,
                label: 'Version',
                value: '${AppInfo.version} (${AppInfo.build})',
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Group(
            children: [
              _Row(
                icon: Icons.logout_rounded,
                label: 'Sign out',
                danger: true,
                onTap: () => _signOut(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Avatar with your first letter, your email, and when you joined.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.email, required this.createdAt});

  final String? email;

  /// When the account was made, as text from Supabase (e.g. "2026-10-21T…").
  final String? createdAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shownEmail = email ?? 'Not signed in';
    final initial = shownEmail.isEmpty ? '?' : shownEmail[0].toUpperCase();
    final joined = DateTime.tryParse(createdAt ?? '');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: context.appColors.incomeSoft,
              foregroundColor: theme.colorScheme.primary,
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shownEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (joined != null)
                    Text(
                      'Member since ${DateFormat.yMMMM().format(joined)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A white card holding rows, with thin lines between them.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            child,
          ],
        ],
      ),
    );
  }
}

/// One settings row: icon, label, and either a value or an arrow.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;

  /// Shown on the right instead of an arrow (for read-only rows).
  final String? value;
  final VoidCallback? onTap;

  /// Red, for "Sign out".
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = danger ? context.appColors.expense : null;
    return ListTile(
      leading: Icon(icon, color: color ?? theme.colorScheme.primary),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      trailing: value != null
          ? Text(
              value!,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            )
          : (onTap == null || danger)
          ? null
          : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
