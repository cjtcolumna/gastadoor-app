import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../supabase/supabase_providers.dart';

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
      if (onLogin) return '/';
      return null; // stay where you are
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
        routes: [
          // A child of home, so the Accounts page gets a back arrow to home.
          GoRoute(
            path: 'accounts',
            name: 'accounts',
            builder: (context, state) => const AccountsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
    ],
  );
});
