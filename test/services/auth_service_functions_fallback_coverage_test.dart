import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/auth_service.dart';

class _FakeAuth implements FirebaseAuth {
  _FakeAuth(this.user);

  final User user;

  @override
  User? get currentUser => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  const _FakeUser(this.id);

  final String id;

  @override
  String get uid => id;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFunctions implements FirebaseFunctions {
  String? requestedName;
  HttpsCallableOptions? requestedOptions;
  final _FakeCallable callable = _FakeCallable();

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
  dynamic receivedParameters;
  var calls = 0;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    calls += 1;
    receivedParameters = parameters;
    return _FakeCallableResult<T>(null as T);
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
  test('sync email utilise le chemin Firebase Functions par défaut', () async {
    final functions = _FakeFunctions();
    final service = AuthService.forTesting(
      auth: _FakeAuth(const _FakeUser('auth-functions-user')),
      firestore: FakeFirebaseFirestore(),
      functions: functions,
    );

    await service.syncEmailVerifiedToFirestore();

    expect(functions.requestedName, 'syncMyEmailVerification');
    expect(functions.requestedOptions?.timeout, const Duration(seconds: 15));
    expect(functions.callable.calls, 1);
    expect(functions.callable.receivedParameters, const <String, dynamic>{});
  });
}
