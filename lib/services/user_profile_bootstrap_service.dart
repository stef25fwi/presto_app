import 'dart:async';

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

  static const String _genericProfileSyncWarningMessage =
      'Connecté, mais le profil n\'a pas pu être synchronisé. Réessaie ou actualise la page.';

  static const String _webAppCheckProfileSyncWarningMessage =
      'Connecté, mais la vérification de sécurité web a échoué. Actualise la page puis réessaie.';

  static const String _profileSyncTimeoutWarningMessage =
      'Connecté, mais la synchronisation du profil a expiré. Réessaie dans quelques secondes.';

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
      await resolvedUser
          .getIdToken(forceRefreshToken)
          .timeout(const Duration(seconds: 8));
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
            .timeout(const Duration(seconds: 8));
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

  static Future<void> ensureUserDocument({
    required User user,
    required String authMethod,
    bool isNewUserHint = false,
  }) async {
    // Reload to get fresh emailVerified state.
    try {
      await user.reload();
    } catch (_) {
      // Best effort — offline or token expired.
    }
    final freshUser = await prepareProfileFirestoreAccess(
          user: FirebaseAuth.instance.currentUser ?? user,
          forceRefreshToken: true,
          forceRefreshAppCheckToken: true,
        ) ??
        FirebaseAuth.instance.currentUser ??
        user;
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(freshUser.uid);
    final email = freshUser.email?.trim().toLowerCase() ?? '';
    final displayName = freshUser.displayName?.trim() ?? '';

    final commonData = <String, dynamic>{
      'uid': freshUser.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'lastAuthMethod': authMethod,
      if (email.isNotEmpty) 'email': email,
      'emailVerified': freshUser.emailVerified,
      if (displayName.isNotEmpty) 'displayName': displayName,
      if (displayName.isNotEmpty) 'pseudo': displayName,
    };

    // Probe existence: try server then cache. If both fail (offline, App
    // Check, timeout) we stay with "existence unknown" and use a safe
    // merge-set so we never throw NOT_FOUND on update().
    bool? docExists;
    if (!isNewUserHint) {
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
    }

    final shouldCreateWithDefaults = isNewUserHint || docExists == false;

    if (shouldCreateWithDefaults) {
      // Fresh profile — atomic set with all defaults. Safe if the doc
      // already exists thanks to merge:true (just refreshes the fields).
      await userRef.set(<String, dynamic>{
        ...commonData,
        'createdAt': FieldValue.serverTimestamp(),
        'accountType': 'Particulier',
        'favoriteCategories': <String>[],
        'selectedFavoriteCategories': <String>[],
        'selectedFavoriteSubcategories': <String>[],
        'profileCompleteness': 0.0,
      }, SetOptions(merge: true));
      return;
    }

    if (docExists == true) {
      // Doc confirmed present — update only known fields and prune stale
      // aliases produced by older builds.
      await userRef.update(<String, dynamic>{
        ...commonData,
        'email_verified': FieldValue.delete(),
        'isEmailVerified': FieldValue.delete(),
      });
      return;
    }

    // Existence unknown (probes failed). Use merge-set to avoid NOT_FOUND.
    // Stale alias cleanup is skipped on this path to keep the write safe;
    // the next successful login will handle it.
    await userRef.set(commonData, SetOptions(merge: true));
  }
}
