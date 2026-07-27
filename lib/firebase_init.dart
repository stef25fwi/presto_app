import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

String firebaseInitPlatformLabel() {
  if (kIsWeb) return 'web';
  return defaultTargetPlatform.name;
}

Future<FirebaseApp> ensureFirebaseInitialized({
  String source = 'app',
}) async {
  final platform = firebaseInitPlatformLabel();
  final existingApp = Firebase.apps.isNotEmpty;
  debugPrint(
    '[FirebaseInit] source=$source platform=$platform existingApp=$existingApp',
  );

  if (existingApp) {
    return Firebase.app();
  }

  try {
    debugPrint(
      '[FirebaseInit] source=$source initializing with DefaultFirebaseOptions.currentPlatform',
    );
    final app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint(
      '[FirebaseInit] source=$source initialized app=${app.name} platform=$platform',
    );
    return app;
  } on FirebaseException catch (error) {
    if (error.code == 'duplicate-app' && Firebase.apps.isNotEmpty) {
      debugPrint(
        '[FirebaseInit] source=$source duplicate app race; reusing ${Firebase.app().name}',
      );
      return Firebase.app();
    }
    debugPrint('[FirebaseInit] source=$source failed: $error');
    rethrow;
  } catch (error) {
    debugPrint('[FirebaseInit] source=$source failed: $error');
    rethrow;
  }
}
