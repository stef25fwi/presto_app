import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/data/marketplace/chat_repository.dart';
import 'package:presto_app/services/marketplace_human_verification.dart';

class _FakeVerification extends MarketplaceHumanVerification {
  MarketplaceHumanVerificationAction? requestedAction;

  @override
  Future<String> obtainToken(
    MarketplaceHumanVerificationAction action,
  ) async {
    requestedAction = action;
    return 'verification-token';
  }
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
    return _FakeCallableResult<T>(
      <String, dynamic>{'threadId': ' thread-default '} as T,
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
  test('utilise les dépendances verification et Functions par défaut', () async {
    final functions = _FakeFunctions();
    final verification = _FakeVerification();
    final repository = ChatRepository(
      functions: functions,
      verification: verification,
    );

    final threadId = await repository.createThreadFromListing(
      listingId: ' listing-default ',
      firstMessage: ' Bonjour depuis le chemin réel ',
    );

    expect(threadId, 'thread-default');
    expect(
      verification.requestedAction,
      MarketplaceHumanVerificationAction.chatFirstMessage,
    );
    expect(functions.requestedName, 'createChatThreadFromListing');
    expect(functions.requestedOptions?.timeout, const Duration(seconds: 20));
    expect(functions.callable.calls, 1);
    expect(functions.callable.receivedParameters, <String, dynamic>{
      'listingId': 'listing-default',
      'message': 'Bonjour depuis le chemin réel',
      'recaptchaToken': 'verification-token',
    });
  });
}
