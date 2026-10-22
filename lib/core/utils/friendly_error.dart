import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart'
    show
        AuthException,
        AuthRetryableFetchException,
        AuthSessionMissingException,
        PostgrestException;

/// Turns any error into one short, plain sentence for the screen.
/// Technical details stay out of the way (they're still in the debug log).
String friendlyError(Object error) {
  if (isOfflineError(error)) {
    return "You're offline. Check your connection and try again.";
  }
  if (error is TimeoutException) {
    return 'The server took too long to answer. Try again.';
  }
  if (error is AuthSessionMissingException) {
    return 'Your sign-in has expired. Please sign in again.';
  }
  if (error is AuthException) {
    // Supabase's own sign-in messages are already readable,
    // e.g. "Invalid login credentials".
    return error.message;
  }
  if (error is PostgrestException) {
    // PGRST301: the sign-in token expired. 42501: Row Level Security said no.
    if (error.code == 'PGRST301') {
      return 'Your sign-in has expired. Please sign in again.';
    }
    if (error.code == '42501') {
      return "You don't have access to that.";
    }
  }
  return 'Something went wrong. Please try again.';
}

/// True when the error means the internet couldn't be reached.
/// On the web there's no special type for this, so the error's text is
/// checked for the usual phrases too.
bool isOfflineError(Object error) {
  if (error is AuthRetryableFetchException) return true;
  final text = error.toString().toLowerCase();
  return const [
    'socketexception',
    'failed host lookup',
    'failed to fetch',
    'xmlhttprequest error',
    'network is unreachable',
    'connection refused',
    'connection closed',
    'clientexception',
  ].any(text.contains);
}
