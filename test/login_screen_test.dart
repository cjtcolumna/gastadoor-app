import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/auth/data/auth_repository.dart';
import 'package:gastadoor/features/auth/presentation/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

/// Stands in for Supabase so tests never touch the real server.
class FakeAuthRepository implements AuthRepository {
  final calls = <String>[];
  bool signUpSignsIn = true;
  AuthException? failWith;

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn $email');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<bool> signUp({required String email, required String password}) async {
    calls.add('signUp $email');
    return signUpSignsIn;
  }

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> changePassword(String newPassword) async =>
      calls.add('changePassword');
}

void main() {
  late FakeAuthRepository fake;

  Future<void> pumpLogin(WidgetTester tester) async {
    fake = FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('shows errors and does not call Supabase when empty', (
    tester,
  ) async {
    await pumpLogin(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('signs in with valid details', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(field('Email'), 'jade@example.com');
    await tester.enterText(field('Password'), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(fake.calls, ['signIn jade@example.com']);
  });

  testWidgets('shows the Supabase error message when sign in fails', (
    tester,
  ) async {
    await pumpLogin(tester);
    fake.failWith = const AuthException('Invalid login credentials');
    await tester.enterText(field('Email'), 'jade@example.com');
    await tester.enterText(field('Password'), 'wrongpass');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Invalid login credentials'), findsOneWidget);
  });

  testWidgets('create account asks to confirm email when needed', (
    tester,
  ) async {
    await pumpLogin(tester);
    fake.signUpSignsIn = false;
    await tester.tap(find.text('New here? Create an account'));
    await tester.pump();
    expect(find.text('Create your account'), findsOneWidget);

    await tester.enterText(field('Email'), 'new@example.com');
    await tester.enterText(field('Password'), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();

    expect(fake.calls, ['signUp new@example.com']);
    expect(
      find.text('Check your email to confirm your account, then sign in.'),
      findsOneWidget,
    );
  });
}
