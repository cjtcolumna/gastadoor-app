import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/utils/friendly_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        AuthException,
        AuthRetryableFetchException,
        AuthSessionMissingException,
        PostgrestException;

void main() {
  const offline = "You're offline. Check your connection and try again.";

  test('no internet, however it shows up, says you are offline', () {
    expect(friendlyError(AuthRetryableFetchException()), offline);
    // On the web:
    expect(
      friendlyError(Exception('ClientException: XMLHttpRequest error.')),
      offline,
    );
    expect(friendlyError(Exception('TypeError: Failed to fetch')), offline);
    // On a phone:
    expect(
      friendlyError(Exception('SocketException: Failed host lookup')),
      offline,
    );
  });

  test('a slow server says so', () {
    expect(
      friendlyError(TimeoutException('slow')),
      'The server took too long to answer. Try again.',
    );
  });

  test("Supabase's readable sign-in messages are kept", () {
    expect(
      friendlyError(const AuthException('Invalid login credentials')),
      'Invalid login credentials',
    );
  });

  test('an expired sign-in asks you to sign in again', () {
    const expired = 'Your sign-in has expired. Please sign in again.';
    expect(friendlyError(AuthSessionMissingException()), expired);
    expect(
      friendlyError(const PostgrestException(message: 'JWT', code: 'PGRST301')),
      expired,
    );
  });

  test('a blocked request says you have no access', () {
    expect(
      friendlyError(const PostgrestException(message: 'rls', code: '42501')),
      "You don't have access to that.",
    );
  });

  test('anything else gets a calm general message', () {
    expect(
      friendlyError(StateError('oops')),
      'Something went wrong. Please try again.',
    );
  });
}
