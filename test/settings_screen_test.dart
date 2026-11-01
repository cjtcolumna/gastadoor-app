import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/config/app_info.dart';
import 'package:gastadoor/core/supabase/supabase_providers.dart';
import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/features/auth/data/auth_repository.dart';
import 'package:gastadoor/features/auth/domain/auth_validators.dart';
import 'package:gastadoor/features/budgets/data/budget_cycle_provider.dart';
import 'package:gastadoor/features/budgets/domain/budget_cycle.dart';
import 'package:gastadoor/features/settings/presentation/settings_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

/// Records what Settings asked for instead of calling Supabase.
class FakeAuth implements AuthRepository {
  final calls = <String>[];

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> changePassword(String newPassword) async =>
      calls.add('changePassword $newPassword');

  @override
  Future<void> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<bool> signUp({required String email, required String password}) =>
      throw UnimplementedError();
}

const jade = User(
  id: 'u1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  email: 'jade@example.com',
  createdAt: '2026-10-21T08:00:00Z',
);

/// Remembers the cycle that was saved instead of calling Supabase.
class FakeCycle extends BudgetCycleNotifier {
  final saved = <BudgetCycle>[];

  @override
  Future<BudgetCycle> build() async => BudgetCycle.calendarMonth;

  @override
  Future<void> save(BudgetCycle cycle) async {
    saved.add(cycle);
    state = AsyncData(cycle);
  }
}

void main() {
  late FakeAuth auth;
  late FakeCycle cycle;

  /// Settings inside a tiny router, so the shortcut rows can navigate.
  Future<void> pumpSettings(
    WidgetTester tester, {
    List<DateTime> salaryDates = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    auth = FakeAuth();
    cycle = FakeCycle();
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(
          path: '/categories',
          builder: (_, _) => const Text('Categories page'),
        ),
        GoRoute(
          path: '/budgets',
          builder: (_, _) => const Text('Budgets page'),
        ),
        GoRoute(
          path: '/accounts',
          builder: (_, _) => const Text('Accounts page'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(jade)),
          authRepositoryProvider.overrideWithValue(auth),
          budgetCycleProvider.overrideWith(() => cycle),
          salaryDatesProvider.overrideWith((ref) async => salaryDates),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows your email, letter avatar, and join date', (tester) async {
    await pumpSettings(tester);
    expect(find.text('jade@example.com'), findsOneWidget);
    expect(find.text('J'), findsOneWidget);
    expect(find.text('Member since October 2026'), findsOneWidget);
    expect(find.text('Philippine peso (₱)'), findsOneWidget);
  });

  testWidgets('shortcut rows open their pages', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.text('Categories page'), findsOneWidget);
  });

  testWidgets('Budget cycle shows the current choice', (tester) async {
    await pumpSettings(tester);
    expect(find.text('Budget cycle'), findsOneWidget);
    expect(find.text('Monthly · 1st'), findsOneWidget);
  });

  testWidgets('Budget cycle can be changed to twice a month', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Budget cycle'));
    await tester.pumpAndSettle();
    // Monthly: only one day to pick.
    expect(find.text('Second period starts on'), findsNothing);

    await tester.tap(find.text('Twice a month'));
    await tester.pumpAndSettle();
    expect(find.text('Second period starts on'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(cycle.saved, [
      const BudgetCycle(
        type: BudgetCycleType.twiceMonthly,
        firstDay: 1,
        secondDay: 15,
      ),
    ]);
    expect(find.text('Budget cycle saved.'), findsOneWidget);
    // The Settings row now describes the new cycle.
    expect(find.text('Twice a month · 1st & 15th'), findsOneWidget);
  });

  testWidgets('On salary has no days to pick, and explains the fallback', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Budget cycle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('On salary'));
    await tester.pumpAndSettle();

    expect(find.text('A new period starts on'), findsNothing);
    expect(find.text('Second period starts on'), findsNothing);
    expect(find.textContaining('not logged a salary yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(cycle.saved.single.type, BudgetCycleType.salary);
    expect(find.text('When I log my salary'), findsOneWidget);
  });

  testWidgets('On salary shows when the current round started', (tester) async {
    final now = DateTime.now();
    await pumpSettings(
      tester,
      salaryDates: [DateTime(now.year, now.month, now.day)],
    );
    await tester.tap(find.text('Budget cycle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('On salary'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Right now: Since '), findsOneWidget);
    expect(find.textContaining('not logged a salary yet'), findsNothing);
  });

  testWidgets('twice a month needs two different days', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Budget cycle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Twice a month'));
    await tester.pumpAndSettle();

    // Make the first day the 15th too (the second is the 15th already).
    await tester.tap(find.text('1st').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15th').last);
    await tester.pumpAndSettle();

    expect(find.text('Pick two different days.'), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('sign out asks first', (tester) async {
    await pumpSettings(tester);
    await tester.ensureVisible(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.calls, isEmpty);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(auth.calls, ['signOut']);
  });

  testWidgets('change password checks both boxes, then saves', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    final newBox = find.widgetWithText(TextFormField, 'New password');
    final againBox = find.widgetWithText(TextFormField, 'Type it again');
    final save = find.widgetWithText(FilledButton, 'Save new password');

    await tester.enterText(newBox, '123');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Use at least 6 characters'), findsOneWidget);

    await tester.enterText(newBox, 'secret123');
    await tester.enterText(againBox, 'secret124');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text("Passwords don't match"), findsOneWidget);
    expect(auth.calls, isEmpty);

    await tester.enterText(againBox, 'secret123');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(auth.calls, ['changePassword secret123']);
    expect(find.text('Password changed.'), findsOneWidget);
  });

  test('confirmPassword rules', () {
    expect(
      AuthValidators.confirmPassword('', 'abc'),
      'Type the password again',
    );
    expect(
      AuthValidators.confirmPassword('abd', 'abc'),
      "Passwords don't match",
    );
    expect(AuthValidators.confirmPassword('abc', 'abc'), isNull);
  });

  test('the version in Settings matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final line = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1)!;
    expect(line, '${AppInfo.version}+${AppInfo.build}');
  });
}
