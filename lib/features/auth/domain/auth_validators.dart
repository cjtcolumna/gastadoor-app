/// Checks for the login form. Each returns an error message,
/// or null when the value is fine (that is what Flutter forms expect).
class AuthValidators {
  const AuthValidators._();

  /// Supabase's default minimum password length.
  static const minPasswordLength = 6;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Enter your password';
    if (password.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters';
    }
    return null;
  }
}
