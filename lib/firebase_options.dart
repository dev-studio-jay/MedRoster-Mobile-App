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
    appId: '1:273151927050:android:51f15edeb7b14a87ed10f3',
    messagingSenderId: '273151927050',
    projectId: 'dev-studio-jay',
    storageBucket: 'dev-studio-jay.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCuDOZuWupCLFPlOUjqsy2XhMJpjeL8qRc',
    appId: '1:273151927050:ios:0a4de7e8bc3ae1e2ed10f3',
    messagingSenderId: '273151927050',
    projectId: 'dev-studio-jay',
    storageBucket: 'dev-studio-jay.firebasestorage.app',
    iosClientId: '273151927050-8qgvdktcic8hsccfcus07u4a9tiutc3v.apps.googleusercontent.com',
    iosBundleId: 'com.blazestudios.medroster',
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