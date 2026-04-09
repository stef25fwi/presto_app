import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Configuration Firebase utilisée par l'application.
///
/// Le repo ne contient actuellement ni `android/app/google-services.json`
/// ni `ios/Runner/GoogleService-Info.plist`. Pour garder un câblage FlutterFire
/// compilable et explicite sur toutes les plateformes, les options natives
/// réutilisent temporairement les valeurs connues du projet Firebase web.
///
/// Dès que les fichiers natifs officiels sont disponibles, régénérer ce fichier
/// avec `flutterfire configure` pour remplacer ces valeurs de fallback.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      case TargetPlatform.fuchsia:
        return web;
    }
  }

  static const String _apiKey = 'AIzaSyB-Oo_86VpG_refQU7my0qk10tQFQDU-Fo';
  static const String _projectId = 'presto-app-74abe';
  static const String _messagingSenderId = '151421230024';
  static const String _storageBucket = 'presto-app-74abe.firebasestorage.app';
  static const String _webAppId = '1:151421230024:web:8b83d1d11084c5a02b3efd';
  static const String _authDomain = 'presto-app-74abe.firebaseapp.com';
  static const String _appleBundleId = 'fr.ilipresto.app';

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _apiKey,
    appId: _webAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: _authDomain,
    storageBucket: _storageBucket,
  );

  // Fallback explicite tant que le projet ne fournit pas son google-services.json.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _apiKey,
    appId: _webAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );

  // Fallback explicite tant que le projet ne fournit pas son GoogleService-Info.plist.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _apiKey,
    appId: _webAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
    iosBundleId: _appleBundleId,
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: _apiKey,
    appId: _webAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
    iosBundleId: _appleBundleId,
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: _apiKey,
    appId: _webAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: _authDomain,
    storageBucket: _storageBucket,
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: _apiKey,
    appId: _webAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: _authDomain,
    storageBucket: _storageBucket,
  );
}
