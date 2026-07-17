import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/app_monitoring_service.dart';

class _OpaqueValue {
  @override
  String toString() => 'opaque-value';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DebugPrintCallback originalDebugPrint;
  late List<String> logs;

  setUp(() {
    logs = <String>[];
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
  });

  test('journalise tous les domaines sans Firebase initialisé', () async {
    final service = AppMonitoringService.instance;

    await service.logInfo(
      scope: 'catalogue',
      action: 'opened',
      message: 'Catalogue ouvert',
      data: <String, dynamic>{'count': 3},
    );
    await service.logWarning(
      scope: 'catalogue',
      action: 'slow',
      message: 'Chargement lent',
      data: <String, dynamic>{'durationMs': 1200},
    );
    await service.logError(
      scope: 'catalogue',
      action: 'failed',
      error: StateError('catalogue indisponible'),
      stack: StackTrace.current,
      data: <String, dynamic>{'retry': true},
    );
    await service.logCritical(
      scope: 'catalogue',
      action: 'critical',
      message: 'Incident critique',
    );
    await service.logAppCheckRefused(
      feature: 'publication',
      data: <String, dynamic>{'attempt': 2},
    );
    await service.logStripePayment(
      action: 'confirmed',
      paymentId: 'pi_test',
      status: 'paid',
      amountCents: 199,
      data: <String, dynamic>{'plan': 'ilipresto_plus'},
    );
    await service.logFcm(
      action: 'token_refreshed',
      tokenStatus: 'ready',
      data: <String, dynamic>{'platform': 'test'},
    );
    await service.logOfferPublication(
      action: 'published',
      offerId: 'offer-1',
      category: 'Jardinage',
      data: <String, dynamic>{'source': 'manual'},
    );
    await service.logMessaging(
      action: 'message_sent',
      conversationId: 'conversation-1',
      data: <String, dynamic>{'kind': 'text'},
    );
    await service.logStorageUpload(
      action: 'uploaded',
      path: 'offers/photo.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 2048,
      data: <String, dynamic>{'compressed': true},
    );
    await service.logAdminAction(
      action: 'listing_hidden',
      target: 'listing-1',
      data: <String, dynamic>{'reason': 'moderation'},
    );
    await service.logAdminConnected(
      adminUid: 'admin-1',
      email: 'admin@example.com',
    );

    expect(logs, hasLength(12));
    expect(
      logs,
      contains(startsWith('[MONITORING][info][catalogue][opened]')),
    );
    expect(
      logs,
      contains(startsWith('[MONITORING][warning][catalogue][slow]')),
    );
    expect(
      logs,
      contains(startsWith('[MONITORING][error][catalogue][failed]')),
    );
    expect(
      logs,
      contains(startsWith('[MONITORING][critical][catalogue][critical]')),
    );
    expect(
      logs,
      contains(startsWith('[MONITORING][warning][app_check][refused]')),
    );
    expect(
      logs,
      contains(startsWith('[MONITORING][info][stripe_payment][confirmed]')),
    );
    expect(logs, contains(startsWith('[MONITORING][info][fcm]')));
    expect(
      logs,
      contains(startsWith('[MONITORING][info][offer_publication]')),
    );
    expect(logs, contains(startsWith('[MONITORING][info][messaging]')));
    expect(logs, contains(startsWith('[MONITORING][info][storage_upload]')));
    expect(logs, contains(startsWith('[MONITORING][warning][admin]')));
    expect(
      logs,
      contains(startsWith('[MONITORING][critical][admin][admin_connected]')),
    );
  });

  test('masque les secrets et borne les données de diagnostic', () async {
    final service = AppMonitoringService.instance;
    final longValue = List<String>.filled(805, 'x').join();

    await service.logEvent(
      level: 'info',
      scope: 'privacy',
      action: 'sanitize',
      data: <String, dynamic>{
        'password': 'mot-de-passe',
        'apiKeyValue': 'cle-api',
        'AuthorizationHeader': 'Bearer secret',
        'safeNumber': 42,
        'safeFlag': true,
        'nested': <String, dynamic>{'city': 'Les Abymes'},
        'opaque': _OpaqueValue(),
        'longText': longValue,
        'nullable': null,
      },
    );
    await service.logEvent(
      level: 'info',
      scope: 'privacy',
      action: 'empty',
    );

    expect(logs, hasLength(2));
    final sanitized = logs.first;
    expect(sanitized, contains('"password":"[redacted]"'));
    expect(sanitized, contains('"apiKeyValue":"[redacted]"'));
    expect(sanitized, contains('"AuthorizationHeader":"[redacted]"'));
    expect(sanitized, contains('"safeNumber":42'));
    expect(sanitized, contains('"safeFlag":true'));
    expect(sanitized, contains('opaque-value'));
    expect(sanitized, contains('...[truncated]'));
    expect(sanitized, isNot(contains('mot-de-passe')));
    expect(sanitized, isNot(contains('cle-api')));
    expect(sanitized, isNot(contains('Bearer secret')));
    expect(
      logs.last,
      startsWith('[MONITORING][info][privacy][empty]'),
    );
  });

  test('installe une seule fois les gestionnaires globaux', () async {
    final originalFlutterError = FlutterError.onError;
    final originalPlatformError = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = originalFlutterError;
      PlatformDispatcher.instance.onError = originalPlatformError;
    });

    final service = AppMonitoringService.instance;
    service.configureGlobalErrorHandling();

    final flutterHandler = FlutterError.onError;
    final platformHandler = PlatformDispatcher.instance.onError;
    expect(flutterHandler, isNotNull);
    expect(platformHandler, isNotNull);

    flutterHandler!(
      FlutterErrorDetails(
        exception: StateError('flutter-boom'),
        stack: StackTrace.current,
        silent: true,
      ),
    );
    final handled = platformHandler!(
      StateError('platform-boom'),
      StackTrace.current,
    );
    await Future<void>.delayed(Duration.zero);

    expect(handled, isFalse);
    expect(
      logs,
      contains(startsWith('[MONITORING][error][frontend][flutter_error]')),
    );
    expect(
      logs,
      contains(startsWith('[MONITORING][error][frontend][platform_error]')),
    );

    service.configureGlobalErrorHandling();
    expect(identical(FlutterError.onError, flutterHandler), isTrue);
    expect(
      identical(PlatformDispatcher.instance.onError, platformHandler),
      isTrue,
    );
  });
}
