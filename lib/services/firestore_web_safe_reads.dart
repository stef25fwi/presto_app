import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Remplace les listeners Firestore Web temps réel par un polling `.get()`.
/// Objectif : éviter le crash Firestore Web:
/// FIRESTORE INTERNAL ASSERTION FAILED: Unexpected state.
extension WebSafeQuerySnapshots on Query<Map<String, dynamic>> {
  Stream<QuerySnapshot<Map<String, dynamic>>> webSafeSnapshots({
    Duration interval = const Duration(seconds: 8),
    String? debugKey,
  }) async* {
    while (true) {
      try {
        yield await get();
      } catch (_) { /* erreur transitoire — stream reste ouvert */ }
      await Future<void>.delayed(interval);
    }
  }
}

extension WebSafeDocumentSnapshots on DocumentReference<Map<String, dynamic>> {
  Stream<DocumentSnapshot<Map<String, dynamic>>> webSafeSnapshots({
    Duration interval = const Duration(seconds: 8),
    String? debugKey,
  }) async* {
    while (true) {
      try {
        yield await get();
      } catch (_) { /* erreur transitoire — stream reste ouvert */ }
      await Future<void>.delayed(interval);
    }
  }
}
