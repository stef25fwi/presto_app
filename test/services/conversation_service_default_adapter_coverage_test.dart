import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/conversation_service.dart';

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
    return _FakeCallableResult<T>(
      <String, dynamic>{'conversationId': ' conversation-default '} as T,
    );
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
  tearDown(() {
    ConversationService.setFunctionCallerForTesting(null);
  });

  test('le caller par défaut utilise le vrai adaptateur Firebase', () async {
    final functions = _FakeFunctions();
    ConversationService.setFirebaseFunctionsForTesting(functions);

    final conversationId = await ConversationService.ensureConversation(
      offerId: 'offer-default',
      offerTitle: 'Titre par défaut',
      currentUserId: 'user-a',
      otherUserId: 'user-b',
      currentUserName: 'Alice',
      otherUserName: 'Bob',
    );

    expect(conversationId, 'conversation-default');
    expect(functions.requestedName, 'ensureOfferConversation');
    expect(functions.requestedOptions?.timeout, const Duration(seconds: 20));
    expect(functions.callable.calls, 1);
    expect(functions.callable.receivedParameters, <String, dynamic>{
      'offerId': 'offer-default',
      'offerTitle': 'Titre par défaut',
      'currentUserId': 'user-a',
      'otherUserId': 'user-b',
      'currentUserName': 'Alice',
      'otherUserName': 'Bob',
    });
  });

  test('le caller par défaut normalise une réponse Firebase non Map', () async {
    final functions = _EmptyFakeFunctions();
    ConversationService.setFirebaseFunctionsForTesting(functions);

    await expectLater(
      ConversationService.ensureConversation(
        offerId: 'offer-empty',
        offerTitle: 'Titre',
        currentUserId: 'user-a',
        otherUserId: 'user-b',
      ),
      throwsA(isA<StateError>()),
    );
  });
}

class _EmptyFakeFunctions implements FirebaseFunctions {
  @override
  HttpsCallable httpsCallable(
    String name, {
    HttpsCallableOptions? options,
  }) {
    return const _EmptyFakeCallable();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyFakeCallable implements HttpsCallable {
  const _EmptyFakeCallable();

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    return _FakeCallableResult<T>(null as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
