// Generated for dev-studio-jay Firebase project.
// Re-run `flutterfire configure` to regenerate if apps change.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('DefaultFirebaseOptions not configured for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBtA67XgypCa-L6A1S76Y3-OoRhVUMr7tA',
    appId: '1:273151927050:android:b4b340fef2344d11ed10f3',
    messagingSenderId: '273151927050',
    projectId: 'dev-studio-jay',
    storageBucket: 'dev-studio-jay.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCuDOZuWupCLFPlOUjqsy2XhMJpjeL8qRc',
    appId: '1:273151927050:ios:0a9fd740d38db42fed10f3',
    messagingSenderId: '273151927050',
    projectId: 'dev-studio-jay',
    storageBucket: 'dev-studio-jay.firebasestorage.app',
    iosBundleId: 'com.medroster.medroster',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCjjPcIF5XyrU88yJAQu1zzLIXKMi8TyyU',
    appId: '1:273151927050:web:a99cb0a039c49832ed10f3',
    messagingSenderId: '273151927050',
    projectId: 'dev-studio-jay',
    authDomain: 'dev-studio-jay.firebaseapp.com',
    storageBucket: 'dev-studio-jay.firebasestorage.app',
    measurementId: 'G-W7TWDZ3N1F',
  );

}