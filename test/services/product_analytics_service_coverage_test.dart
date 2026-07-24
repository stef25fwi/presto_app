import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/cookie_consent_service.dart';
import 'package:presto_app/services/product_analytics_events.dart';
import 'package:presto_app/services/product_analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordedAnalyticsEvent {
  const _RecordedAnalyticsEvent(this.name, this.parameters);

  final String name;
  final Map<String, Object> parameters;
}

class _FakeAnalytics implements FirebaseAnalytics {
  final events = <_RecordedAnalyticsEvent>[];
  bool throwOnLog = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #logEvent) {
      final name = invocation.namedArguments[#name]! as String;
      final rawParameters = invocation.namedArguments[#parameters] as Map?;
      if (throwOnLog) {
        return Future<void>.error(StateError('analytics unavailable'));
      }
      events.add(
        _RecordedAnalyticsEvent(
          name,
          Map<String, Object>.from(rawParameters ?? const <String, Object>{}),
        ),
      );
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeTrace implements Trace {
  _FakeTrace({this.throwOnStart = false, this.throwOnStop = false});

  final bool throwOnStart;
  final bool throwOnStop;
  int startCalls = 0;
  int stopCalls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #start) {
      startCalls += 1;
      if (throwOnStart) {
        return Future<void>.error(StateError('trace start unavailable'));
      }
      return Future<void>.value();
    }
    if (invocation.memberName == #stop) {
      stopCalls += 1;
      if (throwOnStop) {
        return Future<void>.error(StateError('trace stop unavailable'));
      }
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakePerformance implements FirebasePerformance {
  _FakePerformance(this.trace, {this.throwOnNewTrace = false});

  final _FakeTrace trace;
  final bool throwOnNewTrace;
  int newTraceCalls = 0;
  String? lastTraceName;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #newTrace) {
      newTraceCalls += 1;
      lastTraceName = invocation.positionalArguments.single as String;
      if (throwOnNewTrace) {
        throw StateError('newTrace unavailable');
      }
      return trace;
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAnalytics analytics;
  late _FakeTrace trace;
  late _FakePerformance performance;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    analytics = _FakeAnalytics();
    trace = _FakeTrace();
    performance = _FakePerformance(trace);
  });

  ProductAnalyticsService service() {
    return ProductAnalyticsService(
      analytics: analytics,
      performance: performance,
    );
  }

  test('ignore analytics et performance lorsque le consentement est refusé',
      () async {
    await CookieConsentService.instance.refuseAll();
    final current = service();

    await current.logEvent(
      'consent_skipped',
      parameters: <String, Object?>{'value': Object()},
    );
    final result = await current.trace('without_consent', () async => 7);

    expect(result, 7);
    expect(analytics.events, isEmpty);
    expect(performance.newTraceCalls, 0);
  });

  test('journalise un événement nettoyé et un événement produit typé', () async {
    await CookieConsentService.instance.acceptAll();
    final current = service();

    await current.logEvent(
      'sanitized_event',
      parameters: <String, Object?>{
        'string_value': 'ok',
        'number_value': 3,
        'bool_value': true,
        'null_value': null,
        'object_value': DateTime.utc(2026, 1, 2),
      },
    );
    await current.logProductEvent(
      ProductAnalyticsEvent(
        name: 'coverage_product_event',
        stage: ProductFunnelStage.engagement,
        parameters: const <String, Object?>{'channel': 'messages'},
      ),
    );

    expect(analytics.events, hasLength(2));
    expect(analytics.events.first.name, 'sanitized_event');
    expect(
      analytics.events.first.parameters,
      <String, Object>{
        'string_value': 'ok',
        'number_value': 3,
        'bool_value': true,
        'object_value': '2026-01-02 00:00:00.000Z',
      },
    );
    expect(analytics.events.last.name, 'coverage_product_event');
    expect(analytics.events.last.parameters['channel'], 'messages');
    expect(analytics.events.last.parameters['funnel_stage'], 'engagement');
  });

  test('absorbe une erreur Firebase Analytics', () async {
    await CookieConsentService.instance.acceptAll();
    analytics.throwOnLog = true;

    await expectLater(
      service().logEvent('analytics_failure'),
      completes,
    );
    expect(analytics.events, isEmpty);
  });

  test('démarre et arrête une trace autour du résultat', () async {
    await CookieConsentService.instance.acceptAll();

    final result = await service().trace('successful_trace', () async => 'done');

    expect(result, 'done');
    expect(performance.newTraceCalls, 1);
    expect(performance.lastTraceName, 'successful_trace');
    expect(trace.startCalls, 1);
    expect(trace.stopCalls, 1);
  });

  test('arrête la trace lorsque action échoue', () async {
    await CookieConsentService.instance.acceptAll();

    await expectLater(
      service().trace<void>('failing_action', () async {
        throw StateError('action failed');
      }),
      throwsStateError,
    );
    expect(trace.startCalls, 1);
    expect(trace.stopCalls, 1);
  });

  test('continue sans trace lorsque son démarrage échoue', () async {
    await CookieConsentService.instance.acceptAll();
    trace = _FakeTrace(throwOnStart: true);
    performance = _FakePerformance(trace);

    final result = await service().trace('start_failure', () async => 11);

    expect(result, 11);
    expect(trace.startCalls, 1);
    expect(trace.stopCalls, 0);
  });

  test('absorbe une erreur lors de arrêt de la trace', () async {
    await CookieConsentService.instance.acceptAll();
    trace = _FakeTrace(throwOnStop: true);
    performance = _FakePerformance(trace);

    final result = await service().trace('stop_failure', () async => 13);

    expect(result, 13);
    expect(trace.startCalls, 1);
    expect(trace.stopCalls, 1);
  });

  test('continue sans trace lorsque newTrace échoue', () async {
    await CookieConsentService.instance.acceptAll();
    performance = _FakePerformance(trace, throwOnNewTrace: true);

    final result = await service().trace('new_trace_failure', () async => 17);

    expect(result, 17);
    expect(performance.newTraceCalls, 1);
    expect(trace.startCalls, 0);
    expect(trace.stopCalls, 0);
  });
}
