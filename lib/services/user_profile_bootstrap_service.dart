import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/app_check_state.dart';

class UserProfileBootstrapException implements Exception {
  UserProfileBootstrapException(
    this.code,
    this.message, {
    this.cause,
    this.stackTrace,
  });

  final String code;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  bool get isAppCheckFailure =>
      code == 'app-check-unavailable' || code == 'app-check-token-missing';

  bool get isTimeout => code == 'profile-access-timeout';

  @override
  String toString() {
    final causeText = cause == null ? '' : ' cause=$cause';
    return 'UserProfileBootstrapException($code): $message$causeText';
  }
}

class UserProfileBootstrapService {
  UserProfileBootstrapService._();

  static const int _maxAttempts = 3;
  static const Duration _baseBackoff = Duration(seconds: 1);
  static const String _genericProfileSyncWarningMessage =
      'Connecté, mais le profil n\'a pas pu être synchronisé. Réessaie ou actualise la page.';

  static const String _webAppCheckProfileSyncWarningMessage =
      'Connecté, mais la vérification de sécurité web a échoué. Actualise la page puis réessaie.';

  static const String _profileSyncTimeoutWarningMessage =
      'Connecté, mais la synchronisation du profil a expiré. Réessaie dans quelques secondes.';

  /// Per-uid memoization of the last successful bootstrap. Within
  /// [_recentSuccessTtl] of a successful run we skip the redundant
  /// `getIdToken(true)` + Firestore probe round-trip that otherwise gives a
  /// scary "synchronisation a expiré" snackbar when the user simply
  /// navigates back to the account page within a few seconds.
  static final Map<String, DateTime> _lastSuccessByUid = <String, DateTime>{};
  static const Duration _recentSuccessTtl = Duration(minutes: 5);

  /// Returns true when [ensureUserDocument] is allowed to short-circuit:
  /// same uid was successfully synchronised within [_recentSuccessTtl] and
  /// the caller did not request a forced refresh.
  static bool _hasRecentSuccess(String uid) {
    final last = _lastSuccessByUid[uid];
    if (last == null) return false;
    return DateTime.now().difference(last) < _recentSuccessTtl;
  }

  static void _markSuccess(String uid) {
    _lastSuccessByUid[uid] = DateTime.now();
  }

  /// Test helper — clears memoized success markers.
  @visibleForTesting
  static void resetBootstrapMemoForTests() {
    _lastSuccessByUid.clear();
  }

  static String userFacingProfileSyncMessage([Object? error]) {
    final normalizedError = _normalizeBootstrapError(error);
    if (normalizedError.isAppCheckFailure) {
      return _webAppCheckProfileSyncWarningMessage;
    }
    if (normalizedError.isTimeout) {
      return _profileSyncTimeoutWarningMessage;
    }
    return _genericProfileSyncWarningMessage;
  }

  static Future<User?> prepareProfileFirestoreAccess({
    User? user,
    bool forceRefreshToken = false,
    bool forceRefreshAppCheckToken = false,
  }) async {
    User? resolvedUser = user ?? FirebaseAuth.instance.currentUser;
    if (resolvedUser == null) {
      try {
        resolvedUser = await FirebaseAuth.instance
            .authStateChanges()
            .where((candidate) => candidate != null)
            .cast<User>()
            .first
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        resolvedUser = FirebaseAuth.instance.currentUser;
      }
    }

    if (resolvedUser == null) {
      return null;
    }

    try {
      // 12 s tolerates a slow first refresh after sign-in without making the
      // UI feel frozen. Aggressive 8 s timeouts were the root cause of the
      // false-positive "synchronisation a expiré" snackbar.
      await resolvedUser
          .getIdToken(forceRefreshToken)
          .timeout(const Duration(seconds: 12));
    } catch (error) {
      debugPrint('[ProfileFirestore] ID token refresh failed: $error');
      rethrow;
    }

    try {
      await _ensureAppCheckTokenAvailable(
        forceRefreshToken: forceRefreshAppCheckToken,
      );
    } catch (error, stackTrace) {
      debugPrint('[ProfileFirestore] App Check token refresh failed: $error');
      throw _normalizeBootstrapError(error, stackTrace);
    }

    return FirebaseAuth.instance.currentUser ?? resolvedUser;
  }

  static bool isAppCheckFailure(Object? error) {
    return _normalizeBootstrapError(error).isAppCheckFailure;
  }

  static Future<void> _ensureAppCheckTokenAvailable({
    required bool forceRefreshToken,
  }) async {
    if (kIsWeb && appCheckActivationAttempted && !appCheckActivationSucceeded) {
      await _retryWebAppCheckActivation();
    }

    final retryDelays = kIsWeb
        ? const <Duration>[Duration.zero, Duration(milliseconds: 1200)]
        : const <Duration>[Duration.zero];

    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 0; attempt < retryDelays.length; attempt++) {
      final delay = retryDelays[attempt];
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }

      try {
        final appCheckToken = await FirebaseAppCheck.instance
            .getToken(forceRefreshToken || attempt > 0)
            .timeout(const Duration(seconds: 12));
        if ((appCheckToken ?? '').trim().isEmpty) {
          throw UserProfileBootstrapException(
            'app-check-token-missing',
            'Jeton App Check absent pour Firestore profil.',
          );
        }
        return;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        debugPrint(
          '[ProfileFirestore] App Check token attempt ${attempt + 1}/${retryDelays.length} failed: $error',
        );
      }
    }

    throw _normalizeBootstrapError(lastError, lastStackTrace);
  }

  static Future<void> _retryWebAppCheckActivation() async {
    final siteKey = kAppCheckWebRecaptchaSiteKey.trim();
    if (siteKey.isEmpty) {
      throw UserProfileBootstrapException(
        'app-check-unavailable',
        'App Check Web indisponible pour la synchronisation du profil.',
        cause: appCheckActivationError ??
            StateError('APPCHECK_RECAPTCHA_SITE_KEY absente.'),
        stackTrace: appCheckActivationStackTrace,
      );
    }

    try {
      debugPrint('[ProfileFirestore] Retrying App Check web activation');
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaEnterpriseProvider(siteKey),
      );
      appCheckActivationAttempted = true;
      appCheckActivationSucceeded = true;
      appCheckActivationError = null;
      appCheckActivationStackTrace = null;
    } catch (error, stackTrace) {
      appCheckActivationAttempted = true;
      appCheckActivationSucceeded = false;
      appCheckActivationError = error;
      appCheckActivationStackTrace = stackTrace;
      throw UserProfileBootstrapException(
        'app-check-unavailable',
        'App Check Web indisponible pour la synchronisation du profil.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  static UserProfileBootstrapException _normalizeBootstrapError(
    Object? error, [
    StackTrace? stackTrace,
  ]) {
    if (error is UserProfileBootstrapException) {
      return error;
    }
    if (error is TimeoutException) {
      return UserProfileBootstrapException(
        'profile-access-timeout',
        'Délai dépassé pendant l\'accès au profil Firestore.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    final message = (error ?? '').toString().toLowerCase();
    if (message.contains('app check') || message.contains('app_check')) {
      return UserProfileBootstrapException(
        'app-check-unavailable',
        'App Check indisponible pour la synchronisation du profil.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return UserProfileBootstrapException(
      'profile-access-failed',
      'Accès au profil Firestore impossible.',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  static void _logFirestoreSyncError({
    required String operation,
    required String uid,
    required Map<String, dynamic> payload,
    required Object error,
  }) {
    if (error is FirebaseException) {
      debugPrint(
        '[AuthBootstrap][$operation] Firestore error '
        'uid=$uid path=users/$uid code=${error.code} '
        'message=${error.message} payload=$payload',
      );
      return;
    }
    debugPrint(
      '[AuthBootstrap][$operation] error uid=$uid path=users/$uid '
      'error=$error payload=$payload',
    );
  }

  static Future<void> ensureUserDocument({
    required User user,
    required String authMethod,
    bool isNewUserHint = false,
    bool forceRefresh = false,
  }) async {
    // Fast path: if the same uid was successfully synchronised within the
    // memoization TTL and the caller didn't explicitly request a refresh,
    // skip the round-trip. This avoids the false-positive timeout snackbar
    // when AdminSpacePage / AccountPage rapidly re-mount and re-trigger
    // ensureUserDocument while the previous run is still cached.
    if (!forceRefresh && !isNewUserHint && _hasRecentSuccess(user.uid)) {
      debugPrint(
        '[AuthBootstrap] skip uid=${user.uid} reason=recent-success-within-ttl',
      );
      return;
    }

    Object? lastError;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        await _ensureUserDocumentOnce(
          user: user,
          authMethod: authMethod,
          isNewUserHint: isNewUserHint,
          // Force the refresh on the first attempt only. Retries inherit
          // the now-warm token and App Check cache — otherwise every retry
          // pays another 8-16 s of forced refresh latency for no benefit.
          forceRefreshTokens: attempt == 0,
        );
        _markSuccess(user.uid);
        return;
      } on FirebaseException catch (error) {
        lastError = error;
        if (!_isRetryableFirestoreCode(error.code) ||
            attempt == _maxAttempts - 1) {
          rethrow;
        }
        final backoff = _baseBackoff * math.pow(2, attempt).toInt();
        debugPrint(
          '[AuthBootstrap] retry ${attempt + 1}/$_maxAttempts after $backoff '
          'due to code=${error.code}',
        );
        await Future<void>.delayed(backoff);
      } catch (error) {
        lastError = error;
        if (attempt == _maxAttempts - 1) {
          rethrow;
        }
        final backoff = _baseBackoff * math.pow(2, attempt).toInt();
        debugPrint(
          '[AuthBootstrap] retry ${attempt + 1}/$_maxAttempts after $backoff '
          'due to $error',
        );
        await Future<void>.delayed(backoff);
      }
    }
    if (lastError != null) {
      throw lastError;
    }
  }

  static bool _isRetryableFirestoreCode(String code) {
    switch (code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'aborted':
      case 'internal':
      case 'cancelled':
      case 'resource-exhausted':
        return true;
      case 'permission-denied':
      case 'unauthenticated':
      case 'not-found':
      case 'already-exists':
      case 'invalid-argument':
      case 'failed-precondition':
        return false;
      default:
        return true;
    }
  }

  @visibleForTesting
  static bool isRetryableFirestoreCodeForTest(String code) {
    return _isRetryableFirestoreCode(code);
  }

  @visibleForTesting
  static Duration retryBackoffForAttemptForTest(int attempt) {
    if (attempt < 0) {
      throw ArgumentError.value(attempt, 'attempt', 'Must be >= 0');
    }
    return _baseBackoff * math.pow(2, attempt).toInt();
  }

  static Future<void> _ensureUserDocumentOnce({
    required User user,
    required String authMethod,
    required bool isNewUserHint,
    bool forceRefreshTokens = true,
  }) async {
    // Reload to get fresh emailVerified state.
    try {
      await user.reload();
    } catch (_) {
      // Best effort — offline or token expired.
    }
    final freshUser = await prepareProfileFirestoreAccess(
          user: FirebaseAuth.instance.currentUser ?? user,
          forceRefreshToken: forceRefreshTokens,
          forceRefreshAppCheckToken: forceRefreshTokens,
        ) ??
        FirebaseAuth.instance.currentUser ??
        user;
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(freshUser.uid);
    final email = freshUser.email?.trim().toLowerCase() ?? '';
    final displayName = freshUser.displayName?.trim() ?? '';

    final authSyncData = <String, dynamic>{
      'uid': freshUser.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'lastAuthMethod': authMethod,
      if (email.isNotEmpty) 'email': email,
      if (displayName.isNotEmpty) 'displayName': displayName,
      'emailVerified': freshUser.emailVerified,
    };

    final createData = <String, dynamic>{
      ...authSyncData,
      'accountType': 'Particulier',
      if (displayName.isNotEmpty) 'displayName': displayName,
      if (displayName.isNotEmpty) 'pseudo': displayName,
      'profileCompleted': false,
      'profileCompleteness': 0.0,
    };

    // Probe existence: try server then cache. If both fail (offline, App
    // Check, timeout) we stay with "existence unknown" and use a safe
    // merge-set so we never throw NOT_FOUND on update().
    bool? docExists;
    try {
      final existing = await userRef
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 6));
      docExists = existing.exists;
    } catch (serverError) {
      debugPrint(
        '[AuthBootstrap] server probe failed for users/${freshUser.uid}: $serverError',
      );
      try {
        final cached = await userRef
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 3));
        docExists = cached.exists;
      } catch (cacheError) {
        debugPrint(
          '[AuthBootstrap] cache probe failed for users/${freshUser.uid}: $cacheError',
        );
      }
    }

    final payload = docExists == false ? createData : authSyncData;

    try {
      await userRef.set(payload, SetOptions(merge: true));
      return;
    } catch (error) {
      _logFirestoreSyncError(
        operation: docExists == false ? 'create-auth-sync' : 'login-auth-sync',
        uid: freshUser.uid,
        payload: payload,
        error: error,
      );
      rethrow;
    }
  }
}
