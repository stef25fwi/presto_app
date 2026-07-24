import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/admin_broadcast_service.dart';

typedef _CallRecord = ({
  String name,
  Duration? timeout,
  dynamic parameters,
});

class _FakeFunctions implements FirebaseFunctions {
  final List<_CallRecord> calls = <_CallRecord>[];
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  test('construit le service avec la région Firebase de production par défaut',
      () {
    expect(AdminBroadcastService(), isA<AdminBroadcastService>());
  });

  test('BroadcastResult convertit les nombres et neutralise les valeurs invalides',
      () {
    final result = BroadcastResult.fromMap(<String, dynamic>{
      'userCount': 12,
      'tokenCount': 7.9,
      'successCount': '6',
      'failureCount': null,
      'totalUsers': 15.0,
    });

    expect(result.userCount, 12);
    expect(result.tokenCount, 7);
    expect(result.successCount, 0);
    expect(result.failureCount, 0);
    expect(result.totalUsers, 15);
  });

  test('envoie le broadcast avec titre et corps normalisés', () async {
    final functions = _FakeFunctions()
      ..response = <dynamic, dynamic>{
        'userCount': 10,
        'tokenCount': 8,
        'successCount': 7,
        'failureCount': 1,
        'totalUsers': 11,
      };
    final service = AdminBroadcastService(functions: functions);

    final result = await service.sendTestNotificationToAllUsers(
      title: '  Information importante  ',
      body: '  Une notification de test  ',
    );

    expect(result.userCount, 10);
    expect(result.tokenCount, 8);
    expect(result.successCount, 7);
    expect(result.failureCount, 1);
    expect(result.totalUsers, 11);

    final call = functions.calls.single;
    expect(call.name, 'broadcastTestNotification');
    expect(call.timeout, const Duration(seconds: 120));
    expect(call.parameters, <String, dynamic>{
      'title': 'Information importante',
      'body': 'Une notification de test',
    });
  });

  test('omet les textes vides et accepte une réponse non Map', () async {
    final functions = _FakeFunctions()..response = 'invalid-response';
    final service = AdminBroadcastService(functions: functions);

    final result = await service.sendTestNotificationToAllUsers(
      title: '   ',
      body: '',
    );

    expect(functions.calls.single.parameters, isEmpty);
    expect(result.userCount, 0);
    expect(result.tokenCount, 0);
    expect(result.successCount, 0);
    expect(result.failureCount, 0);
    expect(result.totalUsers, 0);
  });
}
