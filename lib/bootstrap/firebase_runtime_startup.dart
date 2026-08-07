import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app/app_runtime_config.dart';
import '../app/runtime_stores.dart';
import '../firebase_init.dart';

Future<void> initializeFirebaseRuntimeServices() async {
  _logFirebaseDiagnostics();
  await _enableFirestoreNetwork();
  await _initializeRemoteConfig();
}

void _logFirebaseDiagnostics() {
  if (!kDebugMode) return;
  debugPrint('=== Firebase Initialization ===');
  debugPrint('[FirebaseInit] ready platform=${firebaseInitPlatformLabel()}');
  debugPrint('✓ Auth instance: ${FirebaseAuth.instance.runtimeType}');
  debugPrint('✓ Firestore instance: ${FirebaseFirestore.instance.runtimeType}');
  debugPrint('[Firestore] initialization ready');
  if (kIsWeb) {
    debugPrint('✓ Platform: Web');
    debugPrint('  - Google Sign-In: Popup + Redirect fallback');
  } else {
    debugPrint('✓ Platform: ${defaultTargetPlatform.toString().split('.').last}');
  }
  debugPrint('');
}

Future<void> _enableFirestoreNetwork() async {
  if (kIsWeb) {
    if (kDebugMode) {
      debugPrint('✓ Firestore Web: Persistence (IndexedDB if available)');
    }
    return;
  }
  try {
    await FirebaseFirestore.instance.enableNetwork();
    if (kDebugMode) debugPrint('✓ Firestore persistence: Enabled');
  } catch (error) {
    if (kDebugMode) debugPrint('⚠️ Firestore persistence error: $error');
  }
}

Future<void> _initializeRemoteConfig() async {
  await PrestoRemoteConfig.init();
  if (kDebugMode) {
    debugPrint('[RC] audio_pipeline=${PrestoRemoteConfig.audioPipeline}');
  }
  adminWebDebugStore.recordEvent(
    area: 'remote-config',
    message: 'initialized',
    detail: 'audio_pipeline=${PrestoRemoteConfig.audioPipeline}',
  );
}
