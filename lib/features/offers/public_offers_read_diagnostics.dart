import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../utils/crashlytics_context.dart';

class PublicOffersReadIssue {
  const PublicOffersReadIssue({
    required this.source,
    required this.kind,
    required this.releaseMessage,
    required this.rawMessage,
    required this.hasAuthenticatedUser,
    required this.appCheckState,
    this.code,
  });

  final String source;
  final String kind;
  final String releaseMessage;
  final String rawMessage;
  final bool hasAuthenticatedUser;
  final String appCheckState;
  final String? code;

  String message({bool debug = kDebugMode}) {
    if (!debug) return releaseMessage;
    return '$releaseMessage\n$debugLine';
  }

  String get debugLine {
    final parts = <String>[
      '[DEBUG OFFERS]',
      'source=$source',
      'kind=$kind',
      if (code != null && code!.trim().isNotEmpty) 'code=$code',
      'auth=${hasAuthenticatedUser ? 'signed-in' : 'public'}',
      'appCheck=$appCheckState',
      if (rawMessage.trim().isNotEmpty)
        'raw=${truncatePublicOffersDebugText(rawMessage)}',
    ];
    return parts.join(' ');
  }
}

class PublicOffersReadException implements Exception {
  const PublicOffersReadException(
    this.issue, {
    this.secondaryIssue,
  });

  final PublicOffersReadIssue issue;
  final PublicOffersReadIssue? secondaryIssue;

  String message({bool debug = kDebugMode}) {
    if (!debug) return issue.releaseMessage;
    if (secondaryIssue == null) return issue.message(debug: true);
    return '${issue.message(debug: true)}\n${secondaryIssue!.debugLine}';
  }

  @override
  String toString() => message(debug: true);
}

String truncatePublicOffersDebugText(String text, {int maxLength = 180}) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= maxLength) return normalized;
  return '${normalized.substring(0, maxLength - 3)}...';
}

String? publicOffersErrorCode(Object error) {
  if (error is PublicOffersReadException) return error.issue.code;
  if (error is FirebaseException && error.code.trim().isNotEmpty) {
    return error.code.trim();
  }

  final message = error.toString().toLowerCase();
  if (message.contains('failed-precondition') || message.contains('index')) {
    return 'failed-precondition';
  }
  if (message.contains('permission-denied')) return 'permission-denied';
  if (message.contains('unauthenticated')) return 'unauthenticated';
  if (message.contains('deadline-exceeded')) return 'deadline-exceeded';
  if (message.contains('unavailable')) return 'unavailable';
  if (message.contains('network')) return 'network';
  return null;
}

PublicOffersReadIssue mergePublicOffersReadIssues({
  required String source,
  required PublicOffersReadIssue primary,
  required PublicOffersReadIssue secondary,
  required String appCheckState,
}) {
  const priority = <String>[
    'app_check',
    'index',
    'rules',
    'auth',
    'network',
    'unknown',
  ];

  PublicOffersReadIssue selected = primary;
  for (final kind in priority) {
    if (primary.kind == kind) {
      selected = primary;
      break;
    }
    if (secondary.kind == kind) {
      selected = secondary;
      break;
    }
  }

  return PublicOffersReadIssue(
    source: source,
    kind: selected.kind,
    code: selected.code,
    releaseMessage: selected.releaseMessage,
    rawMessage: '${primary.source}: ${primary.rawMessage} | '
        '${secondary.source}: ${secondary.rawMessage}',
    hasAuthenticatedUser:
        primary.hasAuthenticatedUser || secondary.hasAuthenticatedUser,
    appCheckState: appCheckState,
  );
}

PublicOffersReadIssue diagnosePublicOffersReadIssue(
  Object error, {
  required String source,
  required String appCheckState,
  bool? hasAuthenticatedUser,
}) {
  if (error is PublicOffersReadException) return error.issue;

  final rawMessage = error.toString().trim();
  final normalized = rawMessage.toLowerCase();
  final code = publicOffersErrorCode(error);
  final effectiveHasAuthenticatedUser =
      hasAuthenticatedUser ?? FirebaseAuth.instance.currentUser != null;
  final hasExplicitAppCheckSignal = normalized.contains('appcheck') ||
      normalized.contains('app check') ||
      normalized.contains('app-check') ||
      normalized.contains('recaptcha') ||
      normalized.contains('attestation');
  final hasTokenSignal = normalized.contains('token') &&
      (normalized.contains('app') ||
          normalized.contains('check') ||
          normalized.contains('attest') ||
          normalized.contains('recaptcha'));
  final isAppCheckIssue = hasExplicitAppCheckSignal || hasTokenSignal;
  final isIndexIssue =
      code == 'failed-precondition' || normalized.contains('index');
  final isPermissionIssue = code == 'permission-denied';
  final isUnauthenticatedIssue = code == 'unauthenticated';
  final isNetworkIssue = code == 'unavailable' ||
      code == 'deadline-exceeded' ||
      code == 'network' ||
      normalized.contains('socketexception') ||
      normalized.contains('xmlhttprequest') ||
      normalized.contains('clientexception') ||
      normalized.contains('network');

  if (isIndexIssue) {
    return PublicOffersReadIssue(
      source: source,
      kind: 'index',
      code: code ?? 'failed-precondition',
      releaseMessage:
          'Les annonces sont en cours de mise à jour. Réessaie dans un instant.',
      rawMessage: rawMessage,
      hasAuthenticatedUser: effectiveHasAuthenticatedUser,
      appCheckState: appCheckState,
    );
  }

  if (isAppCheckIssue) {
    return PublicOffersReadIssue(
      source: source,
      kind: 'app_check',
      code: code ?? 'app-check',
      releaseMessage:
          'Lecture bloquée par la sécurité de l\'application. Vérifie App Check.',
      rawMessage: rawMessage,
      hasAuthenticatedUser: effectiveHasAuthenticatedUser,
      appCheckState: appCheckState,
    );
  }

  if (isPermissionIssue) {
    return PublicOffersReadIssue(
      source: source,
      kind: 'rules',
      code: code,
      releaseMessage:
          'Accès refusé aux annonces publiques. Vérifie les règles Firestore.',
      rawMessage: rawMessage,
      hasAuthenticatedUser: effectiveHasAuthenticatedUser,
      appCheckState: appCheckState,
    );
  }

  if (isUnauthenticatedIssue) {
    return PublicOffersReadIssue(
      source: source,
      kind: 'auth',
      code: code,
      releaseMessage:
          'Lecture impossible des annonces publiques. Vérifie l\'auth Firebase ou la configuration backend.',
      rawMessage: rawMessage,
      hasAuthenticatedUser: effectiveHasAuthenticatedUser,
      appCheckState: appCheckState,
    );
  }

  if (isNetworkIssue) {
    return PublicOffersReadIssue(
      source: source,
      kind: 'network',
      code: code,
      releaseMessage: 'Connexion réseau indisponible.',
      rawMessage: rawMessage,
      hasAuthenticatedUser: effectiveHasAuthenticatedUser,
      appCheckState: appCheckState,
    );
  }

  return PublicOffersReadIssue(
    source: source,
    kind: 'unknown',
    code: code,
    releaseMessage: 'Impossible de charger les annonces pour le moment.',
    rawMessage: rawMessage,
    hasAuthenticatedUser: effectiveHasAuthenticatedUser,
    appCheckState: appCheckState,
  );
}

PublicOffersReadIssue publicOffersReadIssueFromError(
  Object error, {
  required String source,
  required String appCheckState,
  bool? hasAuthenticatedUser,
}) {
  if (error is PublicOffersReadException) return error.issue;
  return diagnosePublicOffersReadIssue(
    error,
    source: source,
    appCheckState: appCheckState,
    hasAuthenticatedUser: hasAuthenticatedUser,
  );
}

String friendlyPublicOffersReadError(
  Object error, {
  required String appCheckState,
  String source = 'public_offers_read',
  bool debug = kDebugMode,
  bool? hasAuthenticatedUser,
}) {
  if (error is PublicOffersReadException) {
    return error.message(debug: debug);
  }
  return diagnosePublicOffersReadIssue(
    error,
    source: source,
    appCheckState: appCheckState,
    hasAuthenticatedUser: hasAuthenticatedUser,
  ).message(debug: debug);
}

void logPublicOffersReadError(
  String source,
  Object error, {
  required String appCheckState,
  StackTrace? stackTrace,
  bool? hasAuthenticatedUser,
}) {
  final issue = publicOffersReadIssueFromError(
    error,
    source: source,
    appCheckState: appCheckState,
    hasAuthenticatedUser: hasAuthenticatedUser,
  );
  final effectiveStackTrace = stackTrace ?? StackTrace.current;

  debugPrint(
    '[PUBLIC_OFFERS][$source] '
    'kind=${issue.kind} '
    'code=${issue.code ?? 'unknown'} '
    'auth=${issue.hasAuthenticatedUser ? 'signed-in' : 'public'} '
    'appCheck=${issue.appCheckState} '
    'type=${error.runtimeType} '
    'message=${issue.rawMessage}',
  );
  if (kDebugMode) {
    debugPrint('[PUBLIC_OFFERS][$source] stack=$effectiveStackTrace');
  }

  unawaited(
    CrashlyticsContext.recordError(
      error,
      effectiveStackTrace,
      reason: 'public offers read failure: $source',
      keys: {
        'public_offers_source': source,
        'public_offers_kind': issue.kind,
        'public_offers_code': issue.code ?? 'unknown',
        'public_offers_auth':
            issue.hasAuthenticatedUser ? 'signed-in' : 'public',
        'public_offers_appcheck': issue.appCheckState,
        'public_offers_message': truncatePublicOffersDebugText(
          issue.rawMessage,
          maxLength: 500,
        ),
      },
    ),
  );
}

Widget buildPublicOffersDebugCard(
  Object error, {
  required String source,
  required String appCheckState,
  bool? hasAuthenticatedUser,
}) {
  if (!kDebugMode) return const SizedBox.shrink();
  final issue = publicOffersReadIssueFromError(
    error,
    source: source,
    appCheckState: appCheckState,
    hasAuthenticatedUser: hasAuthenticatedUser,
  );
  final extra =
      error is PublicOffersReadException && error.secondaryIssue != null
          ? '\n${error.secondaryIssue!.debugLine}'
          : '';

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.amber.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.amber.shade200),
    ),
    child: Text(
      '${issue.debugLine}$extra',
      style: TextStyle(
        fontSize: 11,
        color: Colors.orange.shade900,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}