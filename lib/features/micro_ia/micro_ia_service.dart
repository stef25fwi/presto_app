import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../services/firebase_functions_region.dart';
import '../../utils/crashlytics_context.dart';
import '../../utils/retry.dart';
import 'micro_ia_remote_config.dart';

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

  static final FirebaseFunctions _functions = prestoFirebaseFunctions;
  static final MicroIaRemoteConfig _remoteConfig = MicroIaRemoteConfig();
  static const Duration _kAuthRestoreTimeout = Duration(seconds: 8);
  static const Duration _kCurrentUserBindingTimeout = Duration(seconds: 3);
  static const Duration _kTokenPreemptiveRefreshAge = Duration(minutes: 50);
  static DateTime? _lastForcedTokenRefresh;

  static bool _shouldForceTokenRefresh() {
    final lastRefresh = _lastForcedTokenRefresh;
    return lastRefresh == null ||
        DateTime.now().difference(lastRefresh) > _kTokenPreemptiveRefreshAge;
  }

  static void _log(String stage, String message) {
    debugPrint('[MICIA][$stage] $message');
  }

  static Future<User> requireSignedInUser({
    Duration restoreTimeout = _kAuthRestoreTimeout,
  }) async {
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    if (currentUser != null) return currentUser;
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
      return restoredUser;
    } on TimeoutException {
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
    if (currentUser?.uid == user.uid) return currentUser!;
    try {
      final reboundUser = await auth
          .userChanges()
          .firstWhere((candidate) => candidate?.uid == user.uid)
          .timeout(timeout);
      if (reboundUser == null) {
        throw const MicroIaClientAuthException(
          code: 'auth-not-ready',
          message:
              'La session n’est pas encore synchronisée. Réessaie dans un instant.',
        );
      }
      return reboundUser;
    } on TimeoutException {
      throw const MicroIaClientAuthException(
        code: 'auth-not-ready',
        message:
            'La session n’est pas encore synchronisée. Réessaie dans un instant.',
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
      final idToken = (await boundUser.getIdToken(forceRefreshToken) ?? '').trim();
      if (idToken.isEmpty) {
        throw const MicroIaClientAuthException(
          code: 'token-missing',
          message: 'Session utilisateur invalide. Reconnecte-toi puis réessaie.',
        );
      }
      if (forceRefreshToken) _lastForcedTokenRefresh = DateTime.now();
      return idToken;
    } on MicroIaClientAuthException {
      rethrow;
    } catch (_) {
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
      final normalized = (token ?? '').trim();
      return normalized.isEmpty ? null : normalized;
    } catch (_) {
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
    return MicroIaSecureContext(
      user: boundUser,
      idToken: idToken,
      authSource: FirebaseAuth.instance.currentUser?.uid == boundUser.uid
          ? 'currentUser'
          : 'restored',
      appCheckToken: appCheckToken,
    );
  }

  static String _buildClientRequestId({
    required String uid,
    String? storagePath,
    String? audioBase64,
  }) {
    final source = (storagePath ?? '').isNotEmpty
        ? storagePath!
        : '${(audioBase64 ?? '').length}:${(audioBase64 ?? '').hashCode}';
    return '${DateTime.now().microsecondsSinceEpoch}_${uid.hashCode}_${source.hashCode}';
  }

  static bool _retryableTransportError(Object error) {
    if (error is TimeoutException) return true;
    if (error is! FirebaseFunctionsException) return false;
    return error.code == 'unavailable' || error.code == 'deadline-exceeded';
  }

  static bool _canFallbackToV1(Object error) {
    if (error is TimeoutException) return true;
    if (error is! FirebaseFunctionsException) return false;
    return error.code == 'unavailable' ||
        error.code == 'deadline-exceeded' ||
        error.code == 'internal' ||
        error.code == 'not-found' ||
        error.message == 'AI_PIPELINE_FAILED';
  }

  static Future<Map<String, dynamic>> _invoke({
    required String functionName,
    required Map<String, dynamic> parameters,
    required int maxAttempts,
  }) async {
    final result = await retry(
      () => callPrestoFunction<dynamic>(
        functions: _functions,
        name: functionName,
        timeout: const Duration(seconds: 75),
        parameters: parameters,
      ),
      maxAttempts: maxAttempts,
      retryIf: _retryableTransportError,
    );
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Map<String, dynamic> _buildParameters({
    required MicroIaSecureContext secureContext,
    required String clientRequestId,
    String? storagePath,
    String? audioBase64,
    String? audioContentType,
    String? languageCode,
    bool generateDraft = false,
    String? draftCity,
    String? draftCategory,
    String? debugLabel,
  }) {
    final hasInlineAudio = (audioBase64 ?? '').isNotEmpty;
    return <String, dynamic>{
      if ((storagePath ?? '').isNotEmpty) 'storagePath': storagePath,
      if (hasInlineAudio) 'audioBase64': audioBase64,
      if (hasInlineAudio && audioContentType != null)
        'audioContentType': audioContentType,
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
    };
  }

  static Future<Map<String, dynamic>> processAudio({
    String? storagePath,
    String? audioBase64,
    String? audioContentType,
    String? languageCode,
    bool generateDraft = false,
    String? draftCity,
    String? draftCategory,
    String? debugLabel,
  }) async {
    final hasInlineAudio = (audioBase64 ?? '').isNotEmpty;
    if (!hasInlineAudio && (storagePath ?? '').isEmpty) {
      throw ArgumentError(
        'processAudio requires either storagePath or audioBase64.',
      );
    }

    Future<Map<String, dynamic>> execute(
      MicroIaSecureContext secureContext,
    ) async {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.uid != secureContext.uid) {
        throw const MicroIaClientAuthException(
          code: 'auth-lost',
          message:
              'Session perdue avant l’appel serveur. Reconnecte-toi puis réessaie.',
        );
      }
      await currentUser!.getIdToken(false);
      await _remoteConfig.initialize();
      final clientRequestId = _buildClientRequestId(
        uid: secureContext.uid,
        storagePath: storagePath,
        audioBase64: audioBase64,
      );
      final parameters = _buildParameters(
        secureContext: secureContext,
        clientRequestId: clientRequestId,
        storagePath: storagePath,
        audioBase64: audioBase64,
        audioContentType: audioContentType,
        languageCode: languageCode,
        generateDraft: generateDraft,
        draftCity: draftCity,
        draftCategory: draftCategory,
        debugLabel: debugLabel,
      );
      final useV2 = _remoteConfig.shouldUseV2(secureContext.uid);
      if (!useV2) {
        return _invoke(
          functionName: 'microIaProcessAudio',
          parameters: parameters,
          maxAttempts: 1,
        );
      }
      try {
        final response = await _invoke(
          functionName: 'microIaProcessAudioV2',
          parameters: parameters,
          maxAttempts: 2,
        );
        return <String, dynamic>{
          ...response,
          'clientPipelineSelection': 'v2',
        };
      } catch (error) {
        if (!_remoteConfig.fallbackToV1Enabled || !_canFallbackToV1(error)) {
          rethrow;
        }
        _log(
          'FALLBACK',
          'v2_to_v1 label=${debugLabel ?? 'default'} error=${error.runtimeType}',
        );
        final response = await _invoke(
          functionName: 'microIaProcessAudio',
          parameters: parameters,
          maxAttempts: 1,
        );
        return <String, dynamic>{
          ...response,
          'clientPipelineSelection': 'v1_fallback',
        };
      }
    }

    try {
      final secureContext = await prepareSecureCallableContext(
        forceRefreshToken: _shouldForceTokenRefresh(),
      );
      return await execute(secureContext);
    } on FirebaseFunctionsException catch (error, stackTrace) {
      if (error.code == 'unauthenticated') {
        try {
          final refreshedContext = await prepareSecureCallableContext(
            forceRefreshToken: true,
            forceRefreshAppCheckToken: true,
          );
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
          return await execute(refreshedContext);
        } catch (retryError, retryStackTrace) {
          await CrashlyticsContext.recordError(
            retryError is Exception
                ? retryError
                : Exception(retryError.toString()),
            retryStackTrace,
            reason: 'microIaProcessAudio auth retry failed',
            fatal: false,
            keys: <String, String>{
              'component': 'MicroIaService',
              'function': 'microIaProcessAudio',
              'storagePath': storagePath ?? '(inline)',
              'debugLabel': debugLabel ?? '',
            },
          );
          rethrow;
        }
      }
      await CrashlyticsContext.recordError(
        error,
        stackTrace,
        reason: 'microIaProcessAudio failed',
        fatal: false,
        keys: <String, String>{
          'component': 'MicroIaService',
          'function': 'microIaProcessAudio',
          'storagePath': storagePath ?? '(inline)',
          'languageCode': languageCode ?? '',
          'generateDraft': generateDraft.toString(),
          'debugLabel': debugLabel ?? '',
        },
      );
      rethrow;
    } on MicroIaClientAuthException {
      rethrow;
    } catch (error, stackTrace) {
      await CrashlyticsContext.recordError(
        error is Exception ? error : Exception(error.toString()),
        stackTrace,
        reason: 'microIaProcessAudio failed',
        fatal: false,
        keys: <String, String>{
          'component': 'MicroIaService',
          'function': 'microIaProcessAudio',
          'storagePath': storagePath ?? '(inline)',
          'languageCode': languageCode ?? '',
          'generateDraft': generateDraft.toString(),
          'debugLabel': debugLabel ?? '',
        },
      );
      rethrow;
    }
  }
}
