import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

typedef CrashlyticsUserIdWriter = Future<void> Function(String uid);
typedef CrashlyticsKeyWriter = Future<void> Function(String key, Object value);
typedef CrashlyticsLogger = Future<void> Function(String message);
typedef CrashlyticsErrorRecorder = Future<void> Function(
  Object error,
  StackTrace stack, {
  String? reason,
  bool fatal,
});

/// Helper minimaliste pour enrichir Crashlytics (mobile uniquement).
///
/// - No-op sur le web
/// - Ne lève pas d'exception (best-effort)
class CrashlyticsContext {
  CrashlyticsContext._();

  static FirebaseCrashlytics get _c => FirebaseCrashlytics.instance;

  static CrashlyticsUserIdWriter? _userIdWriter;
  static CrashlyticsKeyWriter? _keyWriter;
  static CrashlyticsLogger? _logger;
  static CrashlyticsErrorRecorder? _errorRecorder;

  static void configureForTest({
    CrashlyticsUserIdWriter? userIdWriter,
    CrashlyticsKeyWriter? keyWriter,
    CrashlyticsLogger? logger,
    CrashlyticsErrorRecorder? errorRecorder,
  }) {
    _userIdWriter = userIdWriter;
    _keyWriter = keyWriter;
    _logger = logger;
    _errorRecorder = errorRecorder;
  }

  static void resetForTest() {
    _userIdWriter = null;
    _keyWriter = null;
    _logger = null;
    _errorRecorder = null;
  }

  static Future<void> setUserId(String? uid) async {
    if (kIsWeb) return;
    try {
      final writer = _userIdWriter ?? _c.setUserIdentifier;
      await writer(uid ?? '');
    } catch (_) {}
  }

  static Future<void> setKey(String key, Object? value) async {
    if (kIsWeb) return;
    try {
      final writer = _keyWriter ?? _c.setCustomKey;
      await writer(key, value ?? '');
    } catch (_) {}
  }

  static Future<void> setKeys(Map<String, Object?> keys) async {
    if (kIsWeb) return;
    for (final entry in keys.entries) {
      await setKey(entry.key, entry.value);
    }
  }

  static Future<void> log(String message) async {
    if (kIsWeb) return;
    try {
      final logger = _logger ?? _c.log;
      await logger(message);
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
      final recorder = _errorRecorder ??
          (
            Object error,
            StackTrace stack, {
            String? reason,
            bool fatal = false,
          }) =>
              _c.recordError(error, stack, reason: reason, fatal: fatal);
      await recorder(error, stack, reason: reason, fatal: fatal);
    } catch (_) {}
  }
}
