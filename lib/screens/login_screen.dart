import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../util/auth_errors.dart';
import '../widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscure = true;
  bool _showPhone = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _afterSignIn() async {
    try {
      await ApiService.instance.loadProfile();
    } catch (_) {}
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signIn(_emailCtrl.text.trim(), _passCtrl.text);
      await _afterSignIn();
    } catch (e) {
      setState(() => _error = mapAuthError(e, 'Sign in failed. Please try again.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithGoogle();
      await _afterSignIn();
    } catch (e) {
      setState(() => _error = mapAuthError(e, 'Google sign-in failed.'));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: AppColors.green.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'MedRoster',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.deep),
              ),
              Text(
                'Ghana Hospital Staff Scheduling',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 32),
              Text('Sign in to your account', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text("Don't have an account? ", style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: () => context.go('/auth/register'),
                    child: const Text('Register'),
                  ),
                  Text(' · ', style: TextStyle(color: AppColors.muted)),
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: () => context.go('/auth/join'),
                    child: const Text('Join hospital'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (!_showPhone) ...[
                GoogleSignInButton(onPressed: _google, loading: _googleLoading, label: 'Sign in with Google'),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => setState(() => _showPhone = true),
                  child: const Text('Sign in with phone (OTP)'),
                ),
                const AuthDivider(),
                Form(
                  key: _formKey,
                  child: Column(children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'Password too short' : null,
                    ),
                  ]),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  AuthErrorBanner(message: _error!),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sign In'),
                ),
              ] else ...[
                PhoneAuthPanel(
                  buttonLabel: 'Send OTP',
                  onVerified: _afterSignIn,
                ),
                TextButton(onPressed: () => setState(() => _showPhone = false), child: const Text('Back to email / Google')),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  AuthErrorBanner(message: _error!),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
