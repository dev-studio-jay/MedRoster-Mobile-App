/// Map Firebase / platform auth errors to user-facing copy (parity with web).
String mapAuthError(Object err, [String fallback = 'Something went wrong. Please try again.']) {
  final raw = err.toString();
  final code = _codeFrom(raw) ?? _codeFromFirebase(err);

  if (code == 'auth/popup-closed-by-user' ||
      code == 'cancelled-popup-request' ||
      code == 'auth/cancelled-popup-request' ||
      raw.contains('sign_in_canceled') ||
      raw.contains('canceled') ||
      raw.contains('cancelled')) {
    return 'Sign-in was cancelled.';
  }
  if (code == 'auth/popup-blocked') {
    return 'Sign-in was blocked. Try again or use email instead.';
  }
  if (code == 'auth/account-exists-with-different-credential') {
    return 'An account already exists with this email using a different sign-in method.';
  }
  if (code == 'auth/operation-not-allowed') {
    return 'Phone OTP is not fully enabled. In Firebase Console enable Phone sign-in, then allow Ghana under Authentication → Settings → SMS region policy.';
  }
  if (code == 'auth/invalid-app-credential' || code == 'auth/captcha-check-failed') {
    return 'Phone verification could not start. Check Firebase app credentials and try again.';
  }
  if (code == 'auth/invalid-credential' ||
      code == 'auth/wrong-password' ||
      code == 'auth/user-not-found' ||
      raw.contains('invalid-credential') ||
      raw.contains('wrong-password') ||
      raw.contains('user-not-found')) {
    return 'Invalid email or password. Please try again.';
  }
  if (code == 'auth/too-many-requests' || raw.contains('too-many-requests')) {
    return 'Too many failed attempts. Please wait a moment and try again.';
  }
  if (code == 'auth/invalid-phone-number' || raw.contains('invalid-phone-number')) {
    return 'Enter a valid Ghana phone number (e.g. 0241234567).';
  }
  if (code == 'auth/invalid-verification-code' || raw.contains('invalid-verification-code')) {
    return 'Invalid OTP code. Please try again.';
  }
  if (code == 'auth/code-expired' ||
      code == 'auth/session-expired' ||
      raw.contains('session-expired') ||
      raw.contains('code-expired')) {
    return 'OTP expired. Request a new code.';
  }
  if (code == 'auth/invalid-email' || raw.contains('invalid-email')) {
    return 'Enter a valid email address.';
  }
  if (code == 'auth/email-already-in-use' || raw.contains('email-already-in-use')) {
    return 'An account with this email already exists. Sign in instead.';
  }
  if (code == 'auth/weak-password' || raw.contains('weak-password')) {
    return 'Password is too weak. Use at least 8 characters.';
  }
  if (code == 'auth/network-request-failed' || raw.contains('network-request-failed')) {
    return 'Network error. Check your connection and try again.';
  }
  if (code == 'auth/user-disabled') {
    return 'This account has been disabled. Contact your hospital admin.';
  }
  if (raw.toLowerCase().contains('region enabled') ||
      (raw.toLowerCase().contains('sms') && raw.toLowerCase().contains('region'))) {
    return 'SMS cannot be sent to Ghana until the region is allowed. Firebase Console → Authentication → Settings → SMS region policy → add Ghana (GH).';
  }
  if (err is Exception && raw.length < 160 && !raw.startsWith('Exception:')) {
    return raw;
  }
  final msg = raw.replaceFirst(RegExp(r'^\[?\w+/?[\w-]*\]?\s*'), '').trim();
  if (msg.isNotEmpty && msg.length < 140 && !msg.contains('Exception')) return msg;
  return fallback;
}

String? _codeFrom(String raw) {
  final m = RegExp(r'(auth/[\w-]+)').firstMatch(raw);
  return m?.group(1);
}

String? _codeFromFirebase(Object err) {
  try {
    // FirebaseAuthException exposes .code
    final dynamic e = err;
    final c = e.code;
    if (c is String && c.isNotEmpty) {
      return c.startsWith('auth/') ? c : 'auth/$c';
    }
  } catch (_) {}
  return null;
}

/// Normalize Ghana phone to E.164 (+233...).
String? toE164Phone(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('233') && digits.length >= 12) return '+$digits';
  if (digits.startsWith('0') && digits.length == 10) return '+233${digits.substring(1)}';
  if (digits.length == 9) return '+233$digits';
  if (input.trim().startsWith('+')) return input.replaceAll(RegExp(r'\s'), '');
  return null;
}
