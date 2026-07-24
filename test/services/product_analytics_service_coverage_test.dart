import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/cookie_consent_service.dart';
import 'package:presto_app/services/product_analytics_events.dart';
import 'package:presto_app/services/product_analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _AnalyticsCall = ({
  String name,
  Map<String, Object>? parameters,
});

class _FakeAnalytics implements FirebaseAnalytics {
  final List<_AnalyticsCall> calls = <_AnalyticsCall>[];
  bool throwOnLog = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #logEvent) {
      if (throwOnLog) {
        return Future<void>.error(StateError('analytics unavailable'));
      }
      final raw = invocation.namedArguments[#parameters];
      calls.add((
        name: invocation.namedArguments[#name] as String,
        parameters: raw == null
            ? null
            : Map<String, Object>.from(raw as Map<dynamic, dynamic>),
      ));
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeTrace implements Trace {
  int startCalls = 0;
  int stopCalls = 0;
  bool throwOnStart = false;
  bool throwOnStop = false;

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
  _FakePerformance(this.trace);

  final _FakeTrace trace;
  final List<String> traceNames = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #newTrace) {
      traceNames.add(invocation.positionalArguments.single as String);
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
  late ProductAnalyticsService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await CookieConsentService.instance.refuseAll();
    analytics = _FakeAnalytics();
    trace = _FakeTrace();
    performance = _FakePerformance(trace);
    service = ProductAnalyticsService(
      analytics: analytics,
      performance: performance,
    );
  });

  test('ignore les événements lorsque le consentement est refusé', () async {
    await service.logEvent(
      'coverage_event',
      parameters: <String, Object?>{'value': 1},
    );

    expect(analytics.calls, isEmpty);
  });

  test('assainit les paramètres et transmet l événement autorisé', () async {
    await CookieConsentService.instance.acceptAll();
    final date = DateTime.utc(2026, 7, 24);

    await service.logEvent(
      'coverage_event',
      parameters: <String, Object?>{
        'text': 'ok',
        'count': 2,
        'enabled': true,
        'ignored': null,
        'object': date,
      },
    );

    expect(analytics.calls, hasLength(1));
    expect(analytics.calls.single.name, 'coverage_event');
    expect(analytics.calls.single.parameters, <String, Object>{
      'text': 'ok',
      'count': 2,
      'enabled': true,
      'object': date.toString(),
    });
  });

  test('logProductEvent délègue vers Firebase Analytics', () async {
    await CookieConsentService.instance.acceptAll();

    await service.logProductEvent(
      ProductAnalyticsEvent.engagementFavoriteChanged(
        listingId: 'listing-1',
        added: true,
      ),
    );

    expect(analytics.calls.single.name, 'engagement_favorite_changed');
    expect(analytics.calls.single.parameters?['listing_id'], 'listing-1');
    expect(analytics.calls.single.parameters?['added'], isTrue);
    expect(analytics.calls.single.parameters?['funnel_stage'], 'engagement');
  });

  test('une erreur Analytics reste best effort', () async {
    await CookieConsentService.instance.acceptAll();
    analytics.throwOnLog = true;

    await expectLater(service.logEvent('coverage_failure'), completes);
  });

  test('trace exécute directement l action sans consentement', () async {
    final result = await service.trace('coverage_trace', () async => 42);

    expect(result, 42);
    expect(performance.traceNames, isEmpty);
    expect(trace.startCalls, 0);
    expect(trace.stopCalls, 0);
  });

  test('trace démarre et arrête Firebase Performance', () async {
    await CookieConsentService.instance.acceptAll();

    final result = await service.trace('coverage_trace', () async => 'ok');

    expect(result, 'ok');
    expect(performance.traceNames, <String>['coverage_trace']);
    expect(trace.startCalls, 1);
    expect(trace.stopCalls, 1);
  });

  test('échec de démarrage de trace ne bloque pas l action', () async {
    await CookieConsentService.instance.acceptAll();
    trace.throwOnStart = true;

    final result = await service.trace('start_failure', () async => 7);

    expect(result, 7);
    expect(trace.startCalls, 1);
    expect(trace.stopCalls, 0);
  });

  test('échec d arrêt de trace reste best effort', () async {
    await CookieConsentService.instance.acceptAll();
    trace.throwOnStop = true;

    final result = await service.trace('stop_failure', () async => 9);

    expect(result, 9);
    expect(trace.startCalls, 1);
    expect(trace.stopCalls, 1);
  });

  test('trace arrête la mesure lorsque l action échoue', () async {
    await CookieConsentService.instance.acceptAll();

    await expectLater(
      service.trace<void>('action_failure', () async {
        throw StateError('action failed');
      }),
      throwsA(isA<StateError>()),
    );
    expect(trace.startCalls, 1);
    expect(trace.stopCalls, 1);
  });
}
