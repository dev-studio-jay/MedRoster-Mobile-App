import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../util/auth_errors.dart';

class AuthService {
  AuthService._() {
    authListenable.value = _auth.currentUser;
    _auth.authStateChanges().listen((user) {
      authListenable.value = user;
    });
  }
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn();
  final ValueNotifier<User?> authListenable = ValueNotifier<User?>(null);

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) {
      throw FirebaseAuthException(code: 'cancelled-popup-request', message: 'cancelled');
    }
    final ga = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: ga.accessToken,
      idToken: ga.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Start phone OTP. Returns verificationId for [confirmPhoneOtp].
  /// If Android auto-verifies, signs in and returns null.
  Future<String?> sendPhoneOtp(String phoneInput) async {
    final phone = toE164Phone(phoneInput);
    if (phone == null) {
      throw FirebaseAuthException(code: 'invalid-phone-number', message: 'Invalid phone');
    }

    final completer = Completer<String?>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          await _auth.signInWithCredential(credential);
          if (!completer.isCompleted) completer.complete(null);
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
    );

    return completer.future;
  }

  Future<UserCredential> confirmPhoneOtp(String verificationId, String smsCode) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken(true);
  }
}
