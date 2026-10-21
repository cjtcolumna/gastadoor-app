import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/supabase/supabase_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supabaseReady = await initSupabase();

  runApp(
    ProviderScope(
      overrides: [supabaseReadyProvider.overrideWithValue(supabaseReady)],
      child: const GastaDoorApp(),
    ),
  );
}
