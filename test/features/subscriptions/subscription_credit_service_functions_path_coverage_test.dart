import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_credit_service.dart';

class _FakeFunctions implements FirebaseFunctions {
  _FakeFunctions(this.response);

  final Map<String, dynamic> response;
  String? requestedName;
  HttpsCallableOptions? requestedOptions;
  late final _FakeCallable callable = _FakeCallable(response);

  @override
  HttpsCallable httpsCallable(
    String name, {
    HttpsCallableOptions? options,
  }) {
    requestedName = name;
    requestedOptions = options;
    return callable;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallable implements HttpsCallable {
  _FakeCallable(this.response);

  final Map<String, dynamic> response;
  dynamic receivedParameters;
  var calls = 0;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    calls += 1;
    receivedParameters = parameters;
    return _FakeCallableResult<T>(response as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallableResult<T> implements HttpsCallableResult<T> {
  const _FakeCallableResult(this.data);

  @override
  final T data;
}

void main() {
  test('getSnapshot exécute le chemin Firebase Functions réel', () async {
    final functions = _FakeFunctions(<String, dynamic>{
      'plan': 'ilipro',
      'period': '2026-07',
      'freeAccessMode': false,
      'nextResetAt': '2026-08-01T00:00:00.000Z',
      'credits': <String, dynamic>{
        'pdf': <String, dynamic>{
          'used': 3,
          'limit': 10,
          'remaining': 7,
          'unlimited': false,
          'exhausted': false,
        },
      },
    });
    final service = SubscriptionCreditService(functions: functions);

    final snapshot = await service.getSnapshot();

    expect(functions.requestedName, 'getMySubscriptionCredits');
    expect(functions.requestedOptions?.timeout, const Duration(seconds: 30));
    expect(functions.callable.calls, 1);
    expect(functions.callable.receivedParameters, isNull);
    expect(snapshot.plan, 'ilipro');
    expect(snapshot.period, '2026-07');
    expect(snapshot.nextResetAt, DateTime.utc(2026, 8));
    expect(snapshot[SubscriptionCreditKind.pdf].used, 3);
    expect(snapshot[SubscriptionCreditKind.pdf].remaining, 7);
  });
}
