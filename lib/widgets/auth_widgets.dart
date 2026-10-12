import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../util/auth_errors.dart';

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 12)),
        ),
        const Expanded(child: Divider()),
      ]),
    );
  }
}

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.label = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: loading
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text('G', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF4285F4))),
                ),
                const SizedBox(width: 10),
                Text(label),
              ],
            ),
    );
  }
}

/// Phone + OTP panel. Calls [onVerified] after Firebase phone sign-in succeeds.
class PhoneAuthPanel extends StatefulWidget {
  final Future<void> Function() onVerified;
  final String buttonLabel;

  const PhoneAuthPanel({
    super.key,
    required this.onVerified,
    this.buttonLabel = 'Continue with phone',
  });

  @override
  State<PhoneAuthPanel> createState() => _PhoneAuthPanelState();
}

class _PhoneAuthPanelState extends State<PhoneAuthPanel> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  String? _verificationId;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = await AuthService.instance.sendPhoneOtp(_phoneCtrl.text.trim());
      if (!mounted) return;
      if (id == null) {
        // Auto-verified on device
        await widget.onVerified();
        return;
      }
      setState(() => _verificationId = id);
    } catch (e) {
      setState(() => _error = mapAuthError(e, 'Failed to send OTP'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    final id = _verificationId;
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.confirmPhoneOtp(id, _otpCtrl.text);
      await widget.onVerified();
    } catch (e) {
      setState(() => _error = mapAuthError(e, 'OTP verification failed'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_verificationId == null) ...[
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '024 123 4567',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loading || _phoneCtrl.text.trim().isEmpty ? null : _send,
            child: Text(_loading ? 'Sending…' : widget.buttonLabel),
          ),
        ] else ...[
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Enter OTP',
              hintText: '6-digit code',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading || _otpCtrl.text.trim().length < 4 ? null : _verify,
            child: Text(_loading ? 'Verifying…' : 'Verify OTP'),
          ),
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                      _verificationId = null;
                      _otpCtrl.clear();
                    }),
            child: const Text('Change number'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  final String message;
  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600, fontSize: 12))),
      ]),
    );
  }
}
