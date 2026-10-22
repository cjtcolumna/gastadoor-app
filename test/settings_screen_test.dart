import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/config/app_info.dart';
import 'package:gastadoor/core/supabase/supabase_providers.dart';
import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/features/auth/data/auth_repository.dart';
import 'package:gastadoor/features/auth/domain/auth_validators.dart';
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

void main() {
  late FakeAuth auth;

  /// Settings inside a tiny router, so the shortcut rows can navigate.
  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    auth = FakeAuth();
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

  testWidgets('sign out asks first', (tester) async {
    await pumpSettings(tester);
    await tester.ensureVisible(find.text('Sign out'));
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
