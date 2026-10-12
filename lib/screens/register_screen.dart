import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../util/auth_errors.dart';
import '../util/ghana_data.dart';
import '../widgets/auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hospitalNameCtrl = TextEditingController();
  final _hospitalLocationCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscure = true;
  bool _showPhone = false;
  String? _error;

  String _hospitalType = hospitalTypes.first;
  String _region = ghanaRegions.contains('Greater Accra') ? 'Greater Accra' : ghanaRegions.first;

  @override
  void dispose() {
    _hospitalNameCtrl.dispose();
    _hospitalLocationCtrl.dispose();
    _adminNameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _hospitalPayload => {
        'hospitalName': _hospitalNameCtrl.text.trim(),
        'hospitalType': _hospitalType,
        'hospitalRegion': _region,
        'hospitalLocation': _hospitalLocationCtrl.text.trim(),
        'accountType': 'enterprise',
      };

  bool _validateHospital() {
    if (_hospitalNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Hospital name is required');
      return false;
    }
    return true;
  }

  Future<void> _goHome() async {
    try {
      await ApiService.instance.loadProfile();
    } catch (_) {}
    if (mounted) context.go('/');
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validateHospital()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiService.instance.post('/api/auth/register', {
        ..._hospitalPayload,
        'region': _region,
        'adminName': _adminNameCtrl.text.trim(),
        'name': _adminNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
      });
      await AuthService.instance.signIn(_emailCtrl.text.trim(), _passCtrl.text);
      await _goHome();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = mapAuthError(e, 'Registration failed. Please try again.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitGoogle() async {
    if (!_validateHospital()) return;
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithGoogle();
      final name = AuthService.instance.currentUser?.displayName ?? _adminNameCtrl.text.trim();
      await ApiService.instance.post('/api/auth/register-google', {
        ..._hospitalPayload,
        'name': name,
      });
      await _goHome();
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        await _goHome();
        return;
      }
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = mapAuthError(e, 'Google registration failed.'));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _afterPhoneVerified() async {
    if (!_validateHospital()) return;
    if (_adminNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name is required for phone registration');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiService.instance.post('/api/auth/register-phone', {
        ..._hospitalPayload,
        'name': _adminNameCtrl.text.trim(),
      });
      await _goHome();
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        await _goHome();
        return;
      }
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = mapAuthError(e, 'Phone registration failed.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Register hospital')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Hospital details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hospitalNameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Hospital name', prefixIcon: Icon(Icons.local_hospital_outlined)),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _hospitalType,
                  decoration: const InputDecoration(labelText: 'Hospital type', prefixIcon: Icon(Icons.category_outlined)),
                  items: hospitalTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _hospitalType = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _region,
                  decoration: const InputDecoration(labelText: 'Region', prefixIcon: Icon(Icons.location_on_outlined)),
                  items: ghanaRegions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setState(() => _region = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hospitalLocationCtrl,
                  decoration: const InputDecoration(labelText: 'Location (optional)', prefixIcon: Icon(Icons.place_outlined)),
                ),
                const SizedBox(height: 24),
                Text('Admin account', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _adminNameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (!_showPhone && (v == null || v.isEmpty)) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                if (!_showPhone) ...[
                  GoogleSignInButton(
                    loading: _googleLoading,
                    label: 'Register with Google',
                    onPressed: _submitGoogle,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => setState(() => _showPhone = true),
                    child: const Text('Register with phone'),
                  ),
                  const AuthDivider(),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined)),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submitEmail(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 8) ? 'Minimum 8 characters' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AuthErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _submitEmail,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create account'),
                  ),
                ] else ...[
                  Text('Name above is required for phone registration.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 12),
                  PhoneAuthPanel(buttonLabel: 'Send OTP', onVerified: _afterPhoneVerified),
                  TextButton(onPressed: () => setState(() => _showPhone = false), child: const Text('Back to email / Google')),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    AuthErrorBanner(message: _error!),
                  ],
                ],
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Already have an account? ', style: TextStyle(color: AppColors.muted)),
                  TextButton(onPressed: () => context.go('/auth/login'), child: const Text('Sign in')),
                  Text(' · ', style: TextStyle(color: AppColors.muted)),
                  TextButton(onPressed: () => context.go('/auth/join'), child: const Text('Join')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
