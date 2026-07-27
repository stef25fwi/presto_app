import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

bool _firestoreBootstrapDone = false;

typedef FirestoreBootstrapApplySettings = Future<void> Function();
typedef FirestoreBootstrapLogger = void Function(String message);

@visibleForTesting
void resetFirestoreBootstrapForTest() {
  _firestoreBootstrapDone = false;
}

Future<void> bootstrapFirestore({
  FirestoreBootstrapApplySettings? applySettings,
  FirestoreBootstrapLogger? logger,
  bool? isWebOverride,
}) async {
  if (_firestoreBootstrapDone) {
    return;
  }

  final isWeb = isWebOverride ?? kIsWeb;
  final log = logger ?? debugPrint;

  try {
    if (isWeb) {
      if (applySettings != null) {
        await applySettings();
      } else {
        FirebaseFirestore.instance.settings =
            const Settings(persistenceEnabled: false);
      }
      if (kDebugMode) {
        log('[Firestore] web settings applied persistence=false');
      }
    }
    _firestoreBootstrapDone = true;
  } catch (error) {
    if (kDebugMode) {
      log('[Firestore] bootstrap failed: $error');
    }
  }
}
