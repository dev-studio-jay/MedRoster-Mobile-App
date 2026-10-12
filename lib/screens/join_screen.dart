import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../util/auth_errors.dart';
import '../widgets/auth_widgets.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  Map<String, dynamic>? _preview;
  bool _loading = false;
  bool _googleLoading = false;
  bool _showPhone = false;
  String? _error;

  bool get _loggedIn => AuthService.instance.currentUser != null;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  String get _joinCode => _codeCtrl.text.trim().toUpperCase();

  Future<void> _lookup() async {
    setState(() {
      _error = null;
      _preview = null;
      _loading = true;
    });
    try {
      if (!_loggedIn) {
        setState(() => _preview = {'pendingAuth': true});
        return;
      }
      if (_joinCode.isEmpty) return;
      final data = await ApiService.instance.get('/api/hospitals/lookup/${Uri.encodeComponent(_joinCode)}');
      setState(() => _preview = Map<String, dynamic>.from(data as Map));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = mapAuthError(e, 'Hospital not found'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance.post('/api/auth/join-hospital', {
        'joinCode': _joinCode,
        if (_nameCtrl.text.trim().isNotEmpty) 'name': _nameCtrl.text.trim(),
      });
      await ApiService.instance.loadProfile();
      if (!mounted) return;
      final hid = (data as Map)['hospitalId']?.toString();
      context.go(hid != null ? '/' : '/');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = mapAuthError(e, 'Failed to join'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ensureAuthThenJoin(Future<void> Function() signIn) async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await signIn();
      await _join();
    } catch (e) {
      setState(() => _error = mapAuthError(e, 'Join failed'));
      if (mounted) setState(() => _loading = false);
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
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.go('/auth/login'),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              Text('Join a hospital', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Ask your admin for the hospital join code.', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500)),
              const SizedBox(height: 24),
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                  UpperCaseTextFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Join code',
                  hintText: 'KBU-X7F',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  hintText: 'Optional if already on Google/phone profile',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              if (_preview != null && _preview!['pendingAuth'] != true) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_preview!['name']?.toString() ?? 'Hospital', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      '${_preview!['type'] ?? ''} · ${_preview!['region'] ?? ''}',
                      style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                AuthErrorBanner(message: _error!),
              ],
              const SizedBox(height: 20),
              if (_loggedIn)
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading || _joinCode.isEmpty ? null : _lookup,
                      child: const Text('Look up'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _loading || _joinCode.isEmpty ? null : _join,
                      child: Text(_loading ? 'Joining…' : 'Join'),
                    ),
                  ),
                ])
              else ...[
                Text(
                  'Sign in first, then we’ll attach you to the hospital.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                GoogleSignInButton(
                  loading: _googleLoading,
                  label: 'Continue with Google',
                  onPressed: () async {
                    setState(() => _googleLoading = true);
                    await _ensureAuthThenJoin(() => AuthService.instance.signInWithGoogle());
                    if (mounted) setState(() => _googleLoading = false);
                  },
                ),
                const SizedBox(height: 10),
                if (!_showPhone)
                  OutlinedButton(
                    onPressed: () => setState(() => _showPhone = true),
                    child: const Text('Continue with phone'),
                  )
                else
                  PhoneAuthPanel(
                    buttonLabel: 'Send OTP',
                    onVerified: () => _ensureAuthThenJoin(() async {}),
                  ),
                TextButton(
                  onPressed: () => context.go('/auth/login'),
                  child: const Text('Or sign in with email'),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(onPressed: () => context.go('/auth/register'), child: const Text('Register hospital')),
                  Text(' · ', style: TextStyle(color: AppColors.muted)),
                  TextButton(onPressed: () => context.go('/auth/login'), child: const Text('Sign in')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
