import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SplashScreenService {
  static const String _defaultVersion = 'v1';

  static Future<String> getActiveSplashscreen() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('splashscreen')
          .get();

      if (doc.exists) {
        final data = doc.data();
        final version = data?['active'] as String?;
        if (version != null && ['v1', 'v2', 'v3'].contains(version)) {
          return version;
        }
      }
    } catch (e) {
      debugPrint('Erreur lecture splashscreen config: $e');
    }

    return _defaultVersion;
  }

  /// Stream pour écouter les changements du splashscreen actif
  static Stream<String> watchActiveSplashscreen() {
    return FirebaseFirestore.instance
        .collection('config')
        .doc('splashscreen')
        .snapshots()
        .map((snap) {
      if (snap.exists) {
        final version = snap.data()?['active'] as String?;
        if (version != null && ['v1', 'v2', 'v3'].contains(version)) {
          return version;
        }
      }
      return _defaultVersion;
    });
  }
}
