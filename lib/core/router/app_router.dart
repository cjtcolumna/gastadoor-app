import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/budgets/presentation/budgets_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/transactions/presentation/history_screen.dart';
import '../supabase/supabase_providers.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final supabaseReady = ref.watch(supabaseReadyProvider);

  // Ticks every time someone signs in or out, so the router re-checks
  // `redirect` below and moves to the right screen.
  final authChanges = ValueNotifier<int>(0);
  ref.listen(currentUserProvider, (_, _) => authChanges.value++);
  ref.onDispose(authChanges.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authChanges,
    redirect: (context, state) {
      // Without Supabase there is no login, so let the home screen
      // show its "not configured" hint.
      if (!supabaseReady) return null;

      final signedIn =
          ref.read(supabaseClientProvider).auth.currentUser != null;
      final onLogin = state.matchedLocation == '/login';

      if (!signedIn) return onLogin ? null : '/login';
      if (onLogin) return '/'; // just signed in: go to the dashboard
      return null; // stay where you are
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      // The three tabs. Each "branch" is one tab with its own history,
      // so switching tabs keeps your place (e.g. the History page number).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  // Opened from Home's "Manage" link; gets a back arrow.
                  GoRoute(
                    path: 'budgets',
                    name: 'budgets',
                    builder: (context, state) => const BudgetsScreen(),
                  ),
                  // Opened from the Categories icon on Home.
                  GoRoute(
                    path: 'categories',
                    name: 'categories',
                    builder: (context, state) => const CategoriesScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/accounts',
                name: 'accounts',
                builder: (context, state) => const AccountsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                name: 'history',
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
