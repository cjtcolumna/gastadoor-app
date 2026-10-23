import 'package:flutter/material.dart';

import '../utils/friendly_error.dart';

/// "Couldn't load…" with a plain-language reason and a Try again button.
///
/// Use [ErrorView] to fill a whole screen, or [ErrorView.inline] inside a
/// section (e.g. one card on Home).
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.title = "Couldn't load this",
  }) : inline = false;

  const ErrorView.inline({
    super.key,
    required this.error,
    required this.onRetry,
    this.title = "Couldn't load this",
  }) : inline = true;

  final Object error;
  final VoidCallback onRetry;
  final String title;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offline = isOfflineError(error);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
          size: inline ? 28 : 44,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          friendlyError(error),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    );

    if (inline) {
      return Card(
        child: Padding(padding: const EdgeInsets.all(20), child: content),
      );
    }
    // A scrollable page, so pull-to-refresh still works on top of it.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Center(
            child: Padding(padding: const EdgeInsets.all(32), child: content),
          ),
        ),
      ),
    );
  }
}
