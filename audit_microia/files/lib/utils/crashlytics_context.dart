import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Helper minimaliste pour enrichir Crashlytics (mobile uniquement).
///
/// - No-op sur le web
/// - Ne lève pas d'exception (best-effort)
class CrashlyticsContext {
  CrashlyticsContext._();

  static FirebaseCrashlytics get _c => FirebaseCrashlytics.instance;

  static Future<void> setUserId(String? uid) async {
    if (kIsWeb) return;
    try {
      await _c.setUserIdentifier(uid ?? '');
    } catch (_) {}
  }

  static Future<void> setKey(String key, Object? value) async {
    if (kIsWeb) return;
    try {
      await _c.setCustomKey(key, value ?? '');
    } catch (_) {}
  }

  static Future<void> setKeys(Map<String, Object?> keys) async {
    if (kIsWeb) return;
    for (final entry in keys.entries) {
      try {
        await _c.setCustomKey(entry.key, entry.value ?? '');
      } catch (_) {}
    }
  }

  static Future<void> log(String message) async {
    if (kIsWeb) return;
    try {
      await _c.log(message);
    } catch (_) {}
  }

  static Future<void> recordError(
    Object error,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
    Map<String, Object?>? keys,
  }) async {
    if (kIsWeb) return;
    try {
      if (keys != null) {
        await setKeys(keys);
      }
      await _c.recordError(error, stack, reason: reason, fatal: fatal);
    } catch (_) {}
  }
}
