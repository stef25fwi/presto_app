import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/data/marketplace/favorite_repository.dart';
import 'package:presto_app/services/product_analytics_events.dart';
import 'package:presto_app/services/product_analytics_service.dart';

typedef _CallableRecord = ({
  String name,
  Duration? timeout,
  dynamic parameters,
});

class _FakeFunctions implements FirebaseFunctions {
  final List<_CallableRecord> calls = <_CallableRecord>[];
  dynamic response;

  @override
  HttpsCallable httpsCallable(
    String name, {
    HttpsCallableOptions? options,
  }) {
    return _FakeCallable(
      owner: this,
      name: name,
      timeout: options?.timeout,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallable implements HttpsCallable {
  const _FakeCallable({
    required this.owner,
    required this.name,
    required this.timeout,
  });

  final _FakeFunctions owner;
  final String name;
  final Duration? timeout;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    owner.calls.add((
      name: name,
      timeout: timeout,
      parameters: parameters,
    ));
    return _FakeCallableResult<T>(owner.response as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallableResult<T> implements HttpsCallableResult<T> {
  const _FakeCallableResult(this.data);

  @override
  final T data;
}

class _FakePerformance implements FirebasePerformance {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAnalytics extends ProductAnalyticsService {
  _FakeAnalytics() : super(performance: _FakePerformance());

  final List<ProductAnalyticsEvent> events = <ProductAnalyticsEvent>[];

  @override
  Future<void> logProductEvent(ProductAnalyticsEvent event) async {
    events.add(event);
  }
}

void main() {
  late _FakeFunctions functions;
  late _FakeAnalytics analytics;
  late FavoriteRepository repository;

  setUp(() {
    functions = _FakeFunctions();
    analytics = _FakeAnalytics();
    repository = FavoriteRepository(
      firestore: FakeFirebaseFirestore(),
      functions: functions,
      analytics: analytics,
    );
  });

  test('le callable réel active le favori et journalise le changement', () async {
    functions.response = <String, dynamic>{'active': true};

    final active = await repository.toggleFavorite(' listing-1 ');

    expect(active, isTrue);
    expect(functions.calls, hasLength(1));
    final call = functions.calls.single;
    expect(call.name, 'toggleFavorite');
    expect(call.timeout, const Duration(seconds: 15));
    expect(call.parameters, <String, dynamic>{'listingId': 'listing-1'});

    expect(analytics.events, hasLength(1));
    final event = analytics.events.single;
    expect(event.name, 'engagement_favorite_changed');
    expect(event.stage, ProductFunnelStage.engagement);
    expect(event.parameters['listing_id'], 'listing-1');
    expect(event.parameters['added'], isTrue);
    expect(event.parameters['funnel_stage'], 'engagement');
  });

  test('une réponse callable vide désactive le favori', () async {
    functions.response = null;

    final active = await repository.toggleFavorite('listing-2');

    expect(active, isFalse);
    expect(functions.calls.single.parameters, <String, dynamic>{
      'listingId': 'listing-2',
    });
    expect(analytics.events.single.parameters['added'], isFalse);
  });
}
