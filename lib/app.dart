import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class GastaDoorApp extends ConsumerWidget {
  const GastaDoorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'GastaDoor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Always light, for a clean look (no dark mode for now).
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
