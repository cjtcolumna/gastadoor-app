import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

/// The only place that talks to Supabase Auth (sign in, sign up, sign out).
/// Screens call these methods instead of using Supabase directly.
class AuthRepository {
  AuthRepository(this._auth);

  final GoTrueClient _auth;

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Creates an account. Returns true when the user is signed in right away,
  /// or false when Supabase wants them to confirm their email first.
  Future<bool> signUp({required String email, required String password}) async {
    final response = await _auth.signUp(
      email: email.trim(),
      password: password,
    );
    return response.session != null;
  }

  Future<void> signOut() => _auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider).auth),
);
