import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'firebase_functions_region.dart';

class AppMonitoringService {
  AppMonitoringService._();

  static final AppMonitoringService instance = AppMonitoringService._();

  static const String appBuild =
      String.fromEnvironment('APP_BUILD', defaultValue: 'dev');

  static const String gitCommit =
      String.fromEnvironment('GIT_COMMIT', defaultValue: 'unknown');

  static const String buildTime =
      String.fromEnvironment('BUILD_TIME', defaultValue: 'unknown');

  bool _configured = false;

  void configureGlobalErrorHandling() {
    if (_configured) return;
    _configured = true;

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);

      unawaited(
        logError(
          scope: 'frontend',
          action: 'flutter_error',
          message: details.exceptionAsString(),
          error: details.exception,
          stack: details.stack,
        ),
      );
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      unawaited(
        logError(
          scope: 'frontend',
          action: 'platform_error',
          message: error.toString(),
          error: error,
          stack: stack,
        ),
      );

      return false;
    };
  }

  Future<void> logInfo({
    required String scope,
    required String action,
    String? message,
    Map<String, dynamic>? data,
  }) {
    return logEvent(
      level: 'info',
      scope: scope,
      action: action,
      message: message,
      data: data,
    );
  }

  Future<void> logWarning({
    required String scope,
    required String action,
    String? message,
    Map<String, dynamic>? data,
  }) {
    return logEvent(
      level: 'warning',
      scope: scope,
      action: action,
      message: message,
      data: data,
    );
  }

  Future<void> logError({
    required String scope,
    required String action,
    String? message,
    Object? error,
    StackTrace? stack,
    Map<String, dynamic>? data,
  }) {
    return logEvent(
      level: 'error',
      scope: scope,
      action: action,
      message: message ?? error?.toString(),
      data: <String, dynamic>{
        if (data != null) ...data,
        if (error != null) 'error': error.toString(),
        if (stack != null) 'stack': stack.toString(),
      },
    );
  }

  Future<void> logCritical({
    required String scope,
    required String action,
    String? message,
    Map<String, dynamic>? data,
  }) {
    return logEvent(
      level: 'critical',
      scope: scope,
      action: action,
      message: message,
      data: data,
    );
  }

  Future<void> logAppCheckRefused({
    String? feature,
    String? reason,
    Map<String, dynamic>? data,
  }) {
    return logWarning(
      scope: 'app_check',
      action: 'refused',
      message: reason ?? 'App Check refusé',
      data: <String, dynamic>{
        if (feature != null) 'feature': feature,
        if (data != null) ...data,
      },
    );
  }

  Future<void> logStripePayment({
    required String action,
    String? paymentId,
    String? status,
    int? amountCents,
    Map<String, dynamic>? data,
  }) {
    return logInfo(
      scope: 'stripe_payment',
      action: action,
      message: status,
      data: <String, dynamic>{
        if (paymentId != null) 'paymentId': paymentId,
        if (status != null) 'status': status,
        if (amountCents != null) 'amountCents': amountCents,
        if (data != null) ...data,
      },
    );
  }

  Future<void> logFcm({
    required String action,
    String? tokenStatus,
    Map<String, dynamic>? data,
  }) {
    return logInfo(
      scope: 'fcm',
      action: action,
      message: tokenStatus,
      data: data,
    );
  }

  Future<void> logOfferPublication({
    required String action,
    String? offerId,
    String? category,
    Map<String, dynamic>? data,
  }) {
    return logInfo(
      scope: 'offer_publication',
      action: action,
      data: <String, dynamic>{
        if (offerId != null) 'offerId': offerId,
        if (category != null) 'category': category,
        if (data != null) ...data,
      },
    );
  }

  Future<void> logMessaging({
    required String action,
    String? conversationId,
    Map<String, dynamic>? data,
  }) {
    return logInfo(
      scope: 'messaging',
      action: action,
      data: <String, dynamic>{
        if (conversationId != null) 'conversationId': conversationId,
        if (data != null) ...data,
      },
    );
  }

  Future<void> logStorageUpload({
    required String action,
    String? path,
    String? mimeType,
    int? sizeBytes,
    Map<String, dynamic>? data,
  }) {
    return logInfo(
      scope: 'storage_upload',
      action: action,
      data: <String, dynamic>{
        if (path != null) 'path': path,
        if (mimeType != null) 'mimeType': mimeType,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
        if (data != null) ...data,
      },
    );
  }

  Future<void> logAdminAction({
    required String action,
    String? target,
    Map<String, dynamic>? data,
  }) {
    return logWarning(
      scope: 'admin',
      action: action,
      message: target,
      data: data,
    );
  }

  Future<void> logAdminConnected({
    String? adminUid,
    String? email,
  }) {
    return logCritical(
      scope: 'admin',
      action: 'admin_connected',
      message: 'Compte admin connecté',
      data: <String, dynamic>{
        if (adminUid != null) 'adminUid': adminUid,
        if (email != null) 'email': email,
      },
    );
  }

  Future<void> logEvent({
    required String level,
    required String scope,
    required String action,
    String? message,
    Map<String, dynamic>? data,
  }) async {
    final cleanedData = _cleanData(data);

    debugPrint(
      '[MONITORING][$level][$scope][$action] '
      '${message ?? ''} '
      '${cleanedData.isEmpty ? '' : jsonEncode(cleanedData)}',
    );

    if (Firebase.apps.isEmpty) return;

    try {
      await callPrestoFunction<dynamic>(
        functions: prestoFirebaseFunctions,
        name: 'reportClientMonitoringEvent',
        timeout: const Duration(seconds: 8),
        area: 'monitoring',
        parameters: <String, dynamic>{
          'createdAtClient': DateTime.now().toUtc().toIso8601String(),
          'level': level,
          'scope': scope,
          'action': action,
          'message': _sanitizeValue(message),
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'releaseMode': kReleaseMode,
          'appBuild': appBuild,
          'gitCommit': gitCommit,
          'buildTime': buildTime,
          'data': cleanedData,
        },
      );
    } catch (error) {
      debugPrint('[MONITORING][write_failed] $error');
    }
  }

  Map<String, dynamic> _cleanData(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return <String, dynamic>{};

    final result = <String, dynamic>{};

    const blockedKeys = <String>{
      'password',
      'token',
      'idtoken',
      'accesstoken',
      'refreshtoken',
      'secret',
      'stripesecret',
      'apikey',
      'authorization',
      'card',
      'iban',
    };

    for (final entry in data.entries) {
      final key = entry.key;
      final lowerKey = key.toLowerCase();

      if (blockedKeys.any(lowerKey.contains)) {
        result[key] = '[redacted]';
        continue;
      }

      result[key] = _sanitizeValue(entry.value);
    }

    return result;
  }

  Object? _sanitizeValue(Object? value) {
    if (value == null) return null;

    if (value is num || value is bool) return value;

    String text;

    if (value is String) {
      text = value;
    } else {
      try {
        text = jsonEncode(value);
      } catch (_) {
        text = value.toString();
      }
    }

    if (text.length <= 800) return text;

    return '${text.substring(0, 800)}...[truncated]';
  }
}
