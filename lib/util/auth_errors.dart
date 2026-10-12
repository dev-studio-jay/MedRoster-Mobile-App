/// Map Firebase / platform auth errors to user-facing copy (parity with web).
String mapAuthError(Object err, [String fallback = 'Something went wrong. Please try again.']) {
  final raw = err.toString();
  final code = _codeFrom(raw);

  if (code == 'auth/popup-closed-by-user' ||
      code == 'auth/cancelled-popup-request' ||
      raw.contains('sign_in_canceled') ||
      raw.contains('canceled')) {
    return 'Sign-in was cancelled.';
  }
  if (code == 'auth/account-exists-with-different-credential') {
    return 'An account already exists with this email using a different sign-in method.';
  }
  if (code == 'auth/operation-not-allowed') {
    return 'This sign-in method is not enabled. Check Firebase Authentication settings.';
  }
  if (code == 'auth/invalid-credential' ||
      code == 'auth/wrong-password' ||
      code == 'auth/user-not-found' ||
      raw.contains('invalid-credential') ||
      raw.contains('wrong-password')) {
    return 'Incorrect email or password.';
  }
  if (code == 'auth/too-many-requests' || raw.contains('too-many-requests')) {
    return 'Too many attempts. Try again later.';
  }
  if (code == 'auth/invalid-phone-number' || raw.contains('invalid-phone-number')) {
    return 'Enter a valid Ghana phone number (e.g. 0241234567).';
  }
  if (code == 'auth/invalid-verification-code' || raw.contains('invalid-verification-code')) {
    return 'That OTP is incorrect. Try again.';
  }
  if (code == 'auth/session-expired' || raw.contains('session-expired')) {
    return 'OTP expired. Request a new code.';
  }
  if (raw.toLowerCase().contains('region enabled') || raw.toLowerCase().contains('sms')) {
    return 'SMS cannot be sent until Ghana is allowed in Firebase SMS region policy.';
  }
  if (err is Exception && raw.length < 160 && !raw.startsWith('Exception:')) {
    return raw;
  }
  final msg = raw.replaceFirst(RegExp(r'^\[?\w+/?[\w-]*\]?\s*'), '').trim();
  if (msg.isNotEmpty && msg.length < 140 && !msg.contains('Exception')) return msg;
  return fallback;
}

String? _codeFrom(String raw) {
  final m = RegExp(r'\[?(auth/[\w-]+)\]?').firstMatch(raw);
  return m?.group(1);
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
