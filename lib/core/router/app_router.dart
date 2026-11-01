import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/account_detail_screen.dart';
import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/budgets/presentation/budget_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/insights/presentation/insights_screen.dart';
import '../../features/loans/presentation/loan_detail_screen.dart';
import '../../features/loans/presentation/loans_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
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
      // The four tabs. Each "branch" is one tab with its own history,
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
                    path: 'budget',
                    name: 'budget',
                    builder: (context, state) => const BudgetScreen(),
                  ),
                  // Opened from Home's Loans section. `/loans/:id` is one loan.
                  _loansRoute(),
                  // Opened from Home's Spending section.
                  GoRoute(
                    path: 'insights',
                    name: 'insights',
                    builder: (context, state) => const InsightsScreen(),
                  ),
                  // Opened from the gear icon on Home.
                  GoRoute(
                    path: 'settings',
                    name: 'settings',
                    builder: (context, state) => const SettingsScreen(),
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
                routes: [
                  // One account's page, e.g. /accounts/1234 for GoTyme.
                  // The `:id` part is read from the address.
                  GoRoute(
                    path: ':id',
                    name: 'account',
                    builder: (context, state) => AccountDetailScreen(
                      accountId: state.pathParameters['id']!,
                    ),
                  ),
                ],
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
          // The More tab: a menu. Its screens live under /more, so opening
          // one from here keeps you in this tab with a back arrow to the
          // menu. (Home has its own /budget and /loans for its "Manage"
          // links, so those keep you on Home.)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                name: 'more',
                builder: (context, state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'budget',
                    name: 'more-budget',
                    builder: (context, state) => const BudgetScreen(),
                  ),
                  _loansRoute(namePrefix: 'more-'),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// The Loans list and, inside it, one loan (`:id`). Used under both Home
/// and More, so the same screens work from either tab.
GoRoute _loansRoute({String namePrefix = ''}) => GoRoute(
  path: 'loans',
  name: '${namePrefix}loans',
  builder: (context, state) => const LoansScreen(),
  routes: [
    GoRoute(
      path: ':id',
      name: '${namePrefix}loan',
      builder: (context, state) =>
          LoanDetailScreen(loanId: state.pathParameters['id']!),
    ),
  ],
);
