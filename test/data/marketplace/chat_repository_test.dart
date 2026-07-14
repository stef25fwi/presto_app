import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/data/marketplace/chat_repository.dart';
import 'package:presto_app/data/marketplace/chat_request_policy.dart';
import 'package:presto_app/services/marketplace_human_verification.dart';

void main() {
  test('crée une conversation avec un jeton explicite normalisé', () async {
    String? calledName;
    Duration? calledTimeout;
    Map<String, dynamic>? calledParameters;
    var verificationCalls = 0;
    final repository = ChatRepository(
      caller: ({required name, required timeout, required parameters}) async {
        calledName = name;
        calledTimeout = timeout;
        calledParameters = parameters;
        return <String, dynamic>{'threadId': ' thread-1 '};
      },
      verificationTokenProvider: (action) async {
        verificationCalls += 1;
        return 'token-inattendu';
      },
    );

    final threadId = await repository.createThreadFromListing(
      listingId: ' listing-1 ',
      firstMessage: ' Bonjour ',
      recaptchaToken: ' token-explicite ',
    );

    expect(threadId, 'thread-1');
    expect(calledName, 'createChatThreadFromListing');
    expect(calledTimeout, const Duration(seconds: 20));
    expect(calledParameters, <String, dynamic>{
      'listingId': 'listing-1',
      'message': 'Bonjour',
      'recaptchaToken': 'token-explicite',
    });
    expect(verificationCalls, 0);
  });

  test('obtient un jeton humain lorsque le jeton explicite manque', () async {
    MarketplaceHumanVerificationAction? requestedAction;
    Map<String, dynamic>? calledParameters;
    final repository = ChatRepository(
      caller: ({required name, required timeout, required parameters}) async {
        calledParameters = parameters;
        return <String, dynamic>{'conversationId': 'conversation-2'};
      },
      verificationTokenProvider: (action) async {
        requestedAction = action;
        return 'token-généré';
      },
    );

    final threadId = await repository.createThreadFromListing(
      listingId: 'listing-2',
      firstMessage: 'Premier message',
      recaptchaToken: '   ',
    );

    expect(threadId, 'conversation-2');
    expect(
      requestedAction,
      MarketplaceHumanVerificationAction.chatFirstMessage,
    );
    expect(calledParameters?['recaptchaToken'], 'token-généré');
  });

  test('propage une erreur du fournisseur de jeton avant le callable',
      () async {
    var calls = 0;
    final repository = ChatRepository(
      caller: ({required name, required timeout, required parameters}) async {
        calls += 1;
        return <String, dynamic>{'threadId': 'thread'};
      },
      verificationTokenProvider: (action) async {
        throw StateError('jeton indisponible');
      },
    );

    await expectLater(
      repository.createThreadFromListing(
        listingId: 'listing-2',
        firstMessage: 'Premier message',
      ),
      throwsStateError,
    );
    expect(calls, 0);
  });

  test(
    'refuse une réponse de création sans identifiant de conversation',
    () async {
      final repository = ChatRepository(
        caller: ({required name, required timeout, required parameters}) async {
          return <String, dynamic>{'ok': true};
        },
      );

      await expectLater(
        repository.createThreadFromListing(
          listingId: 'listing-2',
          firstMessage: 'Premier message',
          recaptchaToken: 'token',
        ),
        throwsA(isA<ChatRequestException>()),
      );
    },
  );

  test('envoie un message avec un payload normalisé', () async {
    String? calledName;
    Duration? calledTimeout;
    Map<String, dynamic>? calledParameters;
    final repository = ChatRepository(
      caller: ({required name, required timeout, required parameters}) async {
        calledName = name;
        calledTimeout = timeout;
        calledParameters = parameters;
        return null;
      },
    );

    await repository.sendMessage(threadId: ' thread-3 ', message: ' Réponse ');

    expect(calledName, 'sendChatMessage');
    expect(calledTimeout, const Duration(seconds: 20));
    expect(calledParameters, <String, dynamic>{
      'threadId': 'thread-3',
      'message': 'Réponse',
    });
  });

  test('bloque les entrées invalides avant tout appel externe', () async {
    var calls = 0;
    final repository = ChatRepository(
      caller: ({required name, required timeout, required parameters}) async {
        calls += 1;
        return null;
      },
    );

    await expectLater(
      repository.sendMessage(threadId: ' ', message: 'Message'),
      throwsA(isA<ChatRequestException>()),
    );
    await expectLater(
      repository.sendMessage(threadId: 'thread', message: ' '),
      throwsA(isA<ChatRequestException>()),
    );
    await expectLater(
      repository.createThreadFromListing(
        listingId: ' ',
        firstMessage: 'Message',
        recaptchaToken: 'token',
      ),
      throwsA(isA<ChatRequestException>()),
    );
    expect(calls, 0);
  });

  test('propage une erreur de callable sans la masquer', () async {
    final repository = ChatRepository(
      caller: ({required name, required timeout, required parameters}) async {
        throw StateError('functions indisponibles');
      },
    );

    await expectLater(
      repository.sendMessage(threadId: 'thread', message: 'Message'),
      throwsStateError,
    );
  });
}
