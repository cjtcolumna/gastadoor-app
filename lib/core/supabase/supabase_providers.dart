import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Initializes Supabase if the URL and publishable key were provided at build time.
/// Returns false when they are missing so the app can still start.
Future<bool> initSupabase() async {
  if (!Env.hasSupabase) return false;
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  return true;
}

/// Overridden in `main.dart` with the result of [initSupabase].
final supabaseReadyProvider = Provider<bool>((ref) => false);

/// The Supabase client. Only read this when [supabaseReadyProvider] is true.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Emits the signed-in user (or null) whenever auth state changes.
final currentUserProvider = StreamProvider<User?>((ref) {
  if (!ref.watch(supabaseReadyProvider)) return Stream.value(null);
  final auth = ref.watch(supabaseClientProvider).auth;
  return auth.onAuthStateChange
      .map((event) => event.session?.user)
      .distinct((a, b) => a?.id == b?.id);
});
