import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Configuration Firebase utilisée par l'application.
///
/// Générée/alignee depuis Firebase CLI pour le projet `presto-app-74abe`.
/// Les plateformes natives utilisent leurs vrais App IDs Firebase, pas l'App ID
/// web, afin d'éviter les mélanges App Check/Auth/FCM en production.
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

  static const String _projectId = 'presto-app-74abe';
  static const String _messagingSenderId = '151421230024';
  static const String _storageBucket = 'presto-app-74abe.firebasestorage.app';
  static const String _databaseURL =
      'https://presto-app-74abe-default-rtdb.europe-west1.firebasedatabase.app';
  static const String _webApiKey = 'AIzaSyCXzhQcvFnlcApEhk8A-Y57IdQC8uO728c';
  static const String _webAppId = '1:151421230024:web:1f974719da2f98822b3efd';
  static const String _authDomain = 'ilipresto.fr';
  static const String _androidApiKey =
      'AIzaSyDAKDN2nDDad4BKxbBVgfYyOqhy7nrtZsQ';
  static const String _androidAppId =
      '1:151421230024:android:339090c7418b3d7c2b3efd';
  static const String _androidClientId =
      '151421230024-9qrsnlo537n1l3dcokep345me3bt8hl5.apps.googleusercontent.com';
  static const String _iosApiKey = 'AIzaSyBuf1j4W60LqaqCdjygCJAQQUuvzYxS0tk';
  static const String _iosAppId = '1:151421230024:ios:c3a75745c492983d2b3efd';
  static const String _iosClientId =
      '151421230024-m5vd41dnda0chqb1e9drm23cvp2vr00e.apps.googleusercontent.com';
  static const String _appleBundleId = 'fr.ilipresto.app';

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCXzhQcvFnlcApEhk8A-Y57IdQC8uO728c',
    appId: '1:151421230024:web:1f974719da2f98822b3efd',
    messagingSenderId: '151421230024',
    projectId: 'presto-app-74abe',
    authDomain: 'ilipresto.fr',
    databaseURL:
        'https://presto-app-74abe-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'presto-app-74abe.firebasestorage.app',
    measurementId: 'G-NT4PEHQ3CJ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDAKDN2nDDad4BKxbBVgfYyOqhy7nrtZsQ',
    appId: '1:151421230024:android:339090c7418b3d7c2b3efd',
    messagingSenderId: '151421230024',
    projectId: 'presto-app-74abe',
    databaseURL:
        'https://presto-app-74abe-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'presto-app-74abe.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBuf1j4W60LqaqCdjygCJAQQUuvzYxS0tk',
    appId: '1:151421230024:ios:c3a75745c492983d2b3efd',
    messagingSenderId: '151421230024',
    projectId: 'presto-app-74abe',
    databaseURL:
        'https://presto-app-74abe-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'presto-app-74abe.firebasestorage.app',
    androidClientId:
        '151421230024-2hri7o8thhcjsrs56pjbq7qfgh8m9q3v.apps.googleusercontent.com',
    iosClientId:
        '151421230024-m5vd41dnda0chqb1e9drm23cvp2vr00e.apps.googleusercontent.com',
    iosBundleId: 'fr.ilipresto.app',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: _iosApiKey,
    appId: _iosAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: _authDomain,
    databaseURL: _databaseURL,
    storageBucket: _storageBucket,
    iosClientId: _iosClientId,
    iosBundleId: _appleBundleId,
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: _webApiKey,
    appId: _webAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: _authDomain,
    databaseURL: _databaseURL,
    storageBucket: _storageBucket,
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: _webApiKey,
    appId: _webAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: _authDomain,
    databaseURL: _databaseURL,
    storageBucket: _storageBucket,
  );
}
