import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

bool _firestoreBootstrapDone = false;

Future<void> bootstrapFirestore() async {
  if (_firestoreBootstrapDone) {
    return;
  }

  final firestore = FirebaseFirestore.instance;

  try {
    if (kIsWeb) {
      firestore.settings = const Settings(persistenceEnabled: false);
      if (kDebugMode) {
        debugPrint('[Firestore] web settings applied persistence=false');
      }
    }
    _firestoreBootstrapDone = true;
  } catch (error) {
    if (kDebugMode) {
      debugPrint('[Firestore] bootstrap failed: $error');
    }
  }
}