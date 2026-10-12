import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../util/auth_errors.dart';
import '../util/ghana_data.dart';
import '../util/guest_storage.dart';
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

  /// 0 = account type, 1 = hospital (enterprise), 2 = credentials
  int _step = 0;
  String _accountType = 'enterprise';
  String _hospitalType = hospitalTypes.contains('District Hospital') ? 'District Hospital' : hospitalTypes.first;
  String _region = ghanaRegions.contains('Greater Accra') ? 'Greater Accra' : ghanaRegions.first;

  bool get _isEnterprise => _accountType == 'enterprise';

  @override
  void dispose() {
    _hospitalNameCtrl.dispose();
    _hospitalLocationCtrl.dispose();
    _adminNameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _basePayload => {
        'accountType': _accountType,
        if (_isEnterprise) ...{
          'hospitalName': _hospitalNameCtrl.text.trim(),
          'hospitalType': _hospitalType,
          'hospitalRegion': _region,
          'hospitalLocation': _hospitalLocationCtrl.text.trim(),
        },
      };

  bool _validateHospital() {
    if (!_isEnterprise) return true;
    if (_hospitalNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Hospital name is required');
      return false;
    }
    return true;
  }

  Future<void> _migrateGuestIfNeeded() async {
    if (_accountType != 'individual') return;
    final guest = await takeGuestDataForMigration();
    if (guest == null || guest['startDate'] == null || guest['endDate'] == null) return;
    try {
      await ApiService.instance.post('/api/me/schedules', {
        'name': guest['name'] ?? 'Migrated guest schedule',
        'startDate': guest['startDate'],
        'endDate': guest['endDate'],
        'staff': guest['staff'] ?? [],
        'assignments': guest['assignments'] ?? [],
        'holidays': guest['holidays'] ?? [],
      });
    } catch (_) {}
  }

  Future<void> _goHome() async {
    try {
      await ApiService.instance.loadProfile();
      await _migrateGuestIfNeeded();
    } catch (_) {}
    if (!mounted) return;
    if (ApiService.instance.isIndividualAccount) {
      context.go('/individual');
    } else {
      context.go('/');
    }
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
        ..._basePayload,
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
        ..._basePayload,
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
        ..._basePayload,
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
      appBar: AppBar(
        title: Text(_step == 0 ? 'Create account' : _step == 1 ? 'Hospital details' : 'Your account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 0) {
              context.go('/auth/login');
            } else if (_step == 2 && !_isEnterprise) {
              setState(() => _step = 0);
            } else {
              setState(() => _step -= 1);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == 0) ...[
                  Text('Who is this for?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Pick how you’ll use MedRoster. You can upgrade later.', style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 20),
                  _AccountTypeCard(
                    selected: _accountType == 'individual',
                    title: 'Individual',
                    desc: 'Personal monthly rosters. Save to the cloud. Up to 50 staff.',
                    onTap: () => setState(() => _accountType = 'individual'),
                  ),
                  const SizedBox(height: 10),
                  _AccountTypeCard(
                    selected: _accountType == 'enterprise',
                    title: 'Hospital / Enterprise',
                    desc: 'Full hospital account with departments, wards, join code, and schedules.',
                    onTap: () => setState(() => _accountType = 'enterprise'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => setState(() {
                      _error = null;
                      _step = _isEnterprise ? 1 : 2;
                    }),
                    child: const Text('Continue'),
                  ),
                ],
                if (_step == 1) ...[
                  TextFormField(
                    controller: _hospitalNameCtrl,
                    decoration: const InputDecoration(labelText: 'Hospital name', prefixIcon: Icon(Icons.local_hospital_outlined)),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _hospitalType,
                    decoration: const InputDecoration(labelText: 'Hospital type'),
                    items: hospitalTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _hospitalType = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _region,
                    decoration: const InputDecoration(labelText: 'Region'),
                    items: ghanaRegions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setState(() => _region = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _hospitalLocationCtrl,
                    decoration: const InputDecoration(labelText: 'Location (optional)'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AuthErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      if (_hospitalNameCtrl.text.trim().isEmpty) {
                        setState(() => _error = 'Hospital name is required');
                        return;
                      }
                      setState(() {
                        _error = null;
                        _step = 2;
                      });
                    },
                    child: const Text('Continue'),
                  ),
                ],
                if (_step == 2) ...[
                  TextFormField(
                    controller: _adminNameCtrl,
                    decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => (!_showPhone && (v == null || v.isEmpty)) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  if (!_showPhone) ...[
                    GoogleSignInButton(loading: _googleLoading, label: 'Register with Google', onPressed: _submitGoogle),
                    const SizedBox(height: 10),
                    OutlinedButton(onPressed: () => setState(() => _showPhone = true), child: const Text('Register with phone')),
                    const AuthDivider(),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined)),
                      validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
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
                          : Text(_isEnterprise ? 'Create hospital account' : 'Create individual account'),
                    ),
                  ] else ...[
                    PhoneAuthPanel(buttonLabel: 'Send OTP', onVerified: _afterPhoneVerified),
                    TextButton(onPressed: () => setState(() => _showPhone = false), child: const Text('Back to email / Google')),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      AuthErrorBanner(message: _error!),
                    ],
                  ],
                ],
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton(onPressed: () => context.go('/auth/login'), child: const Text('Sign in')),
                  Text(' · ', style: TextStyle(color: AppColors.muted)),
                  TextButton(onPressed: () => context.go('/guest'), child: const Text('Try as guest')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  final bool selected;
  final String title;
  final String desc;
  final VoidCallback onTap;

  const _AccountTypeCard({
    required this.selected,
    required this.title,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.teal : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
            Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? AppColors.teal : AppColors.muted, size: 20),
          ]),
          const SizedBox(height: 6),
          Text(desc, style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500, height: 1.35)),
        ]),
      ),
    );
  }
}
