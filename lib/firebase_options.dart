import 'package:firebase_core/firebase_core.dart';

/// Options Firebase pour le Web (Flutter)
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // On cible ton build Web (GitHub Pages)
    return const FirebaseOptions(
      apiKey: 'AIzaSyB-Oo_86VpG_refQU7my0qk10tQFQDU-Fo',
      authDomain: 'presto-app-74abe.firebaseapp.com',
      projectId: 'presto-app-74abe',
      storageBucket: 'presto-app-74abe.firebasestorage.app',
      messagingSenderId: '151421230024',
      appId: '1:151421230024:web:deb9b7cb4f744c742b3efd',
      // measurementId: '…', // optionnel, tu peux en ajouter un si Firebase te le donne
    );
  }
}