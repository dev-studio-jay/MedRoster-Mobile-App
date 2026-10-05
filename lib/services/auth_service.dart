import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService._() {
    authListenable.value = _auth.currentUser;
    _auth.authStateChanges().listen((user) {
      authListenable.value = user;
    });
  }
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final ValueNotifier<User?> authListenable = ValueNotifier<User?>(null);

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken(true);
  }
}
