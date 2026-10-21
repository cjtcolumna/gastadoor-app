import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../data/auth_repository.dart';
import '../domain/auth_validators.dart';

/// Sign in or create an account with email and password.
/// After a successful sign in, the router notices and opens the home screen.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _loading = false;
  bool _hidePassword = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final auth = ref.read(authRepositoryProvider);
    final email = _emailController.text;
    final password = _passwordController.text;

    try {
      if (_isSignUp) {
        final signedIn = await auth.signUp(email: email, password: password);
        if (!signedIn && mounted) {
          setState(() {
            _isSignUp = false;
            _info = 'Check your email to confirm your account, then sign in.';
          });
        }
      } else {
        await auth.signIn(email: email, password: password);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Something went wrong. Check your internet connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _error = null;
      _info = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(isSignUp: _isSignUp),
                      const SizedBox(height: 32),
                      _emailField(),
                      const SizedBox(height: 12),
                      _passwordField(),
                      if (_error != null)
                        _Message(text: _error!, isError: true),
                      if (_info != null) _Message(text: _info!),
                      const SizedBox(height: 24),
                      _SubmitButton(
                        label: _isSignUp ? 'Create account' : 'Sign in',
                        loading: _loading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading ? null : _toggleMode,
                        child: Text(
                          _isSignUp
                              ? 'Already have an account? Sign in'
                              : 'New here? Create an account',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailController,
      decoration: const InputDecoration(
        labelText: 'Email',
        prefixIcon: Icon(Icons.mail_outline),
      ),
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      autocorrect: false,
      textInputAction: TextInputAction.next,
      validator: AuthValidators.email,
      enabled: !_loading,
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _hidePassword ? 'Show password' : 'Hide password',
          icon: Icon(
            _hidePassword ? Icons.visibility_outlined : Icons.visibility_off,
          ),
          onPressed: () => setState(() => _hidePassword = !_hidePassword),
        ),
      ),
      obscureText: _hidePassword,
      autofillHints: [
        _isSignUp ? AutofillHints.newPassword : AutofillHints.password,
      ],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      validator: AuthValidators.password,
      enabled: !_loading,
    );
  }
}

/// App icon, name and a short line that changes with the mode.
class _Header extends StatelessWidget {
  const _Header({required this.isSignUp});

  final bool isSignUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            size: 40,
            color: colors.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'GastaDoor',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isSignUp ? 'Create your account' : 'Welcome back',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A red error line or a neutral info line under the form.
class _Message extends StatelessWidget {
  const _Message({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: isError ? colors.error : colors.primary),
      ),
    );
  }
}

/// Full-width button that shows a spinner while waiting for Supabase.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Text(label),
    );
  }
}
