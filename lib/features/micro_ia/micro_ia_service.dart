import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../services/firebase_functions_region.dart';
import '../../utils/crashlytics_context.dart';
import '../../utils/retry.dart';

class MicroIaClientAuthException implements Exception {
  const MicroIaClientAuthException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => message;
}

class MicroIaSecureContext {
  const MicroIaSecureContext({
    required this.user,
    required this.idToken,
    required this.authSource,
    required this.appCheckToken,
  });

  final User user;
  final String idToken;
  final String authSource;
  final String? appCheckToken;

  String get uid => user.uid;
  String? get email => user.email;
  bool get hasAppCheckToken => (appCheckToken ?? '').trim().isNotEmpty;
}

class MicroIaService {
  MicroIaService._();

  static final _functions = prestoFirebaseFunctions;
  static const Duration _kAuthRestoreTimeout = Duration(seconds: 8);
  static const Duration _kCurrentUserBindingTimeout = Duration(seconds: 3);

  static void _log(String stage, String message) {
    debugPrint('[MICIA][$stage] $message');
  }

  static Future<User> requireSignedInUser({
    Duration restoreTimeout = _kAuthRestoreTimeout,
  }) async {
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    if (currentUser != null) {
      _log(
        'AUTH',
        'uid=${currentUser.uid} email=${currentUser.email ?? ''} source=currentUser',
      );
      return currentUser;
    }

    _log('AUTH', 'user=null waiting_session_restore=yes');

    try {
      final restoredUser = await auth
          .authStateChanges()
          .firstWhere((candidate) => candidate != null)
          .timeout(restoreTimeout);
      if (restoredUser == null) {
        throw const MicroIaClientAuthException(
          code: 'auth-missing',
          message: 'Connecte-toi pour utiliser la dictée IA.',
        );
      }

      _log(
        'AUTH',
        'uid=${restoredUser.uid} email=${restoredUser.email ?? ''} source=authStateChanges',
      );
      return restoredUser;
    } on TimeoutException {
      _log('AUTH', 'user=null restore_timeout=yes');
      throw const MicroIaClientAuthException(
        code: 'auth-missing',
        message: 'Connecte-toi pour utiliser la dictée IA.',
      );
    }
  }

  static Future<User> _ensureCurrentUserBound(
    User user, {
    Duration timeout = _kCurrentUserBindingTimeout,
  }) async {
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    if (currentUser != null && currentUser.uid == user.uid) {
      return currentUser;
    }

    _log(
      'AUTH',
      'current_user_mismatch current=${currentUser?.uid ?? 'null'} expected=${user.uid}',
    );

    try {
      final reboundUser = await auth
          .userChanges()
          .firstWhere((candidate) => candidate?.uid == user.uid)
          .timeout(timeout);
      if (reboundUser == null) {
        throw const MicroIaClientAuthException(
          code: 'auth-not-ready',
          message: 'La session n’est pas encore synchronisée. Réessaie dans un instant.',
        );
      }
      _log('AUTH', 'current_user_bound=yes uid=${reboundUser.uid}');
      return reboundUser;
    } on TimeoutException {
      _log('AUTH', 'current_user_bound=no expected=${user.uid}');
      throw const MicroIaClientAuthException(
        code: 'auth-not-ready',
        message: 'La session n’est pas encore synchronisée. Réessaie dans un instant.',
      );
    }
  }

  static Future<String> requireFreshIdToken({
    User? user,
    bool forceRefreshToken = true,
  }) async {
    final boundUser = await _ensureCurrentUserBound(
      user ?? await requireSignedInUser(),
    );

    try {
      final idToken = await boundUser.getIdToken(forceRefreshToken);
      final normalizedToken = (idToken ?? '').trim();
      if (normalizedToken.isEmpty) {
        _log('TOKEN', 'fetched=no uid=${boundUser.uid}');
        throw const MicroIaClientAuthException(
          code: 'token-missing',
          message: 'Session utilisateur invalide. Reconnecte-toi puis réessaie.',
        );
      }
      _log('TOKEN', 'fetched=yes uid=${boundUser.uid}');
      return normalizedToken;
    } catch (error) {
      if (error is MicroIaClientAuthException) rethrow;
      _log('TOKEN', 'fetched=no uid=${boundUser.uid} err=${error.runtimeType}');
      throw const MicroIaClientAuthException(
        code: 'token-missing',
        message: 'Session utilisateur invalide. Reconnecte-toi puis réessaie.',
      );
    }
  }

  static Future<String?> _tryGetAppCheckToken({
    bool forceRefresh = false,
  }) async {
    try {
      final token = await FirebaseAppCheck.instance.getToken(forceRefresh);
      final normalizedToken = (token ?? '').trim();
      _log('APPCHECK', 'fetched=${normalizedToken.isNotEmpty ? 'yes' : 'no'}');
      return normalizedToken.isEmpty ? null : normalizedToken;
    } catch (error) {
      _log('APPCHECK', 'fetched=no err=${error.runtimeType}');
      return null;
    }
  }

  static Future<MicroIaSecureContext> prepareSecureCallableContext({
    bool forceRefreshToken = false,
    bool forceRefreshAppCheckToken = false,
    Duration restoreTimeout = _kAuthRestoreTimeout,
  }) async {
    final signedInUser = await requireSignedInUser(
      restoreTimeout: restoreTimeout,
    );
    final boundUser = await _ensureCurrentUserBound(signedInUser);
    final idToken = await requireFreshIdToken(
      user: boundUser,
      forceRefreshToken: forceRefreshToken,
    );
    final appCheckToken = await _tryGetAppCheckToken(
      forceRefresh: forceRefreshAppCheckToken,
    );
    final authSource = FirebaseAuth.instance.currentUser?.uid == boundUser.uid
        ? 'currentUser'
        : 'restored';

    return MicroIaSecureContext(
      user: boundUser,
      idToken: idToken,
      authSource: authSource,
      appCheckToken: appCheckToken,
    );
  }

  /// Process audio and optionally generate a draft in a single round-trip.
  /// When [generateDraft] is true, the CF merges STT + OpenAI draft
  /// to eliminate one network round-trip (~1-2s saved).
  static Future<Map<String, dynamic>> processAudio({
    required String storagePath,
    String? languageCode,
    bool generateDraft = false,
    String? draftCity,
    String? draftCategory,
    String? debugLabel,
  }) async {
    final clientRequestId =
        '${DateTime.now().millisecondsSinceEpoch}_${storagePath.hashCode}';

    Future<Map<String, dynamic>> invokeCallable(
      MicroIaSecureContext secureContext,
    ) async {
      final callable = _functions.httpsCallable(
        'microIaProcessAudio',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 75)),
      );

      _log(
        'PROCESS',
        'calling backend label=${debugLabel ?? 'default'} uid=${secureContext.uid} authSource=${secureContext.authSource}',
      );

      final res = await retry(
        () => callable.call(<String, dynamic>{
          'storagePath': storagePath,
          if (languageCode != null) 'languageCode': languageCode,
          if (generateDraft) 'generateDraft': true,
          if (generateDraft && draftCity != null) 'draftCity': draftCity,
          if (generateDraft && draftCategory != null)
            'draftCategory': draftCategory,
          'clientRequestId': clientRequestId,
          'clientDebugLabel': debugLabel ?? '',
          'clientAuthUid': secureContext.uid,
          'clientAuthEmail': secureContext.email ?? '',
          'clientAuthSource': secureContext.authSource,
          'clientTokenPresent': secureContext.idToken.isNotEmpty,
          'clientAppCheckTokenPresent': secureContext.hasAppCheckToken,
        }),
        maxAttempts: 3,
        retryIf: (e) {
          if (e is TimeoutException) return true;
          if (e is FirebaseFunctionsException) {
            return e.code == 'unavailable' ||
                e.code == 'deadline-exceeded' ||
                e.code == 'internal' ||
                e.code == 'resource-exhausted';
          }
          return false;
        },
      );

      return Map<String, dynamic>.from(res.data as Map);
    }

    try {
      final secureContext = await prepareSecureCallableContext(
        forceRefreshToken: false,
      );
      return await invokeCallable(secureContext);
    } on FirebaseFunctionsException catch (error, st) {
      if (error.code == 'unauthenticated') {
        _log(
          'PROCESS',
          'auth missing code=${error.code} retrying=yes label=${debugLabel ?? 'default'}',
        );
        try {
          final refreshedContext = await prepareSecureCallableContext(
            forceRefreshToken: true,
            forceRefreshAppCheckToken: true,
          );
          return await invokeCallable(refreshedContext);
        } on FirebaseFunctionsException catch (retryError) {
          _log(
            'PROCESS',
            'auth missing retry_failed code=${retryError.code} label=${debugLabel ?? 'default'}',
          );
          await CrashlyticsContext.recordError(
            retryError,
            st,
            reason: 'microIaProcessAudio auth retry failed',
            fatal: false,
            keys: {
              'component': 'MicroIaService',
              'function': 'microIaProcessAudio',
              'storagePath': storagePath,
              'languageCode': languageCode ?? '',
              'generateDraft': generateDraft.toString(),
              'debugLabel': debugLabel ?? '',
            },
          );
          rethrow;
        }
      }
      await CrashlyticsContext.recordError(
        error,
        st,
        reason: 'microIaProcessAudio failed',
        fatal: false,
        keys: {
          'component': 'MicroIaService',
          'function': 'microIaProcessAudio',
          'storagePath': storagePath,
          'languageCode': languageCode ?? '',
          'generateDraft': generateDraft.toString(),
          'debugLabel': debugLabel ?? '',
        },
      );
      rethrow;
    } on MicroIaClientAuthException {
      rethrow;
    } catch (e, st) {
      await CrashlyticsContext.recordError(
        e is Exception ? e : Exception(e.toString()),
        st,
        reason: 'microIaProcessAudio failed',
        fatal: false,
        keys: {
          'component': 'MicroIaService',
          'function': 'microIaProcessAudio',
          'storagePath': storagePath,
          'languageCode': languageCode ?? '',
          'generateDraft': generateDraft.toString(),
          'debugLabel': debugLabel ?? '',
        },
      );
      rethrow;
    }
  }
}
