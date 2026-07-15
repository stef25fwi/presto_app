import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/conversation_service.dart';

typedef _CallRecord = ({
  String name,
  Duration timeout,
  Map<String, dynamic> parameters,
});

void main() {
  late List<_CallRecord> calls;
  late Map<String, Map<String, dynamic>> responses;

  setUp(() {
    calls = <_CallRecord>[];
    responses = <String, Map<String, dynamic>>{};
    ConversationService.setFunctionCallerForTesting(
      ({
        required String name,
        required Duration timeout,
        required Map<String, dynamic> parameters,
      }) async {
        calls.add((
          name: name,
          timeout: timeout,
          parameters: Map<String, dynamic>.from(parameters),
        ));
        return Map<String, dynamic>.from(
          responses[name] ?? const <String, dynamic>{},
        );
      },
    );
  });

  tearDown(() {
    ConversationService.setFunctionCallerForTesting(null);
  });

  test('sérialise une pièce jointe de conversation', () {
    const attachment = ConversationAttachmentInput(
      type: 'image',
      name: 'photo.webp',
      url: 'https://cdn.test/photo.webp',
      storagePath: 'conversations/c1/photo.webp',
      mimeType: 'image/webp',
      sizeBytes: 2048,
    );

    expect(attachment.toJson(), <String, dynamic>{
      'type': 'image',
      'name': 'photo.webp',
      'url': 'https://cdn.test/photo.webp',
      'storagePath': 'conversations/c1/photo.webp',
      'mimeType': 'image/webp',
      'sizeBytes': 2048,
    });
  });

  test('normalise les réponses de traitement photo', () {
    final numeric = ProcessedConversationPhoto.fromMap(<String, dynamic>{
      'storagePath': 'processed/photo.webp',
      'downloadUrl': 'https://cdn.test/processed.webp',
      'sizeBytes': 12.6,
    });
    expect(numeric.storagePath, 'processed/photo.webp');
    expect(numeric.downloadUrl, 'https://cdn.test/processed.webp');
    expect(numeric.thumbnailUrl, 'https://cdn.test/processed.webp');
    expect(numeric.mimeType, 'image/webp');
    expect(numeric.sizeBytes, 13);

    final textual = ProcessedConversationPhoto.fromMap(<String, dynamic>{
      'thumbnailUrl': 'https://cdn.test/thumb.webp',
      'mimeType': 'image/jpeg',
      'sizeBytes': '42',
    });
    expect(textual.thumbnailUrl, 'https://cdn.test/thumb.webp');
    expect(textual.mimeType, 'image/jpeg');
    expect(textual.sizeBytes, 42);

    final empty = ProcessedConversationPhoto.fromMap(const <String, dynamic>{});
    expect(empty.storagePath, isEmpty);
    expect(empty.downloadUrl, isEmpty);
    expect(empty.thumbnailUrl, isEmpty);
    expect(empty.sizeBytes, 0);
  });

  test('crée ou retrouve une conversation avec le payload complet', () async {
    responses['ensureOfferConversation'] = <String, dynamic>{
      'conversationId': ' conversation-1 ',
    };

    final conversationId = await ConversationService.ensureConversation(
      offerId: 'offer-1',
      offerTitle: 'Besoin de jardinage',
      currentUserId: 'user-a',
      otherUserId: 'user-b',
      currentUserName: 'Alice',
      otherUserName: 'Bob',
    );

    expect(conversationId, 'conversation-1');
    expect(calls.single.name, 'ensureOfferConversation');
    expect(calls.single.timeout, const Duration(seconds: 20));
    expect(calls.single.parameters, <String, dynamic>{
      'offerId': 'offer-1',
      'offerTitle': 'Besoin de jardinage',
      'currentUserId': 'user-a',
      'otherUserId': 'user-b',
      'currentUserName': 'Alice',
      'otherUserName': 'Bob',
    });
  });

  test('refuse une réponse sans identifiant de conversation', () async {
    await expectLater(
      ConversationService.ensureConversation(
        offerId: 'offer-1',
        offerTitle: 'Titre',
        currentUserId: 'user-a',
        otherUserId: 'user-b',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('envoie texte et pièces jointes puis utilise la réponse serveur', () async {
    responses['sendConversationMessage'] = <String, dynamic>{
      'conversationId': 'conversation-server',
    };
    const attachment = ConversationAttachmentInput(
      type: 'document',
      name: 'devis.pdf',
      url: 'https://cdn.test/devis.pdf',
      storagePath: 'conversations/c1/devis.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 4096,
    );

    final conversationId = await ConversationService.sendMessage(
      conversationId: 'conversation-local',
      text: 'Bonjour',
      attachments: const <ConversationAttachmentInput>[attachment],
    );

    expect(conversationId, 'conversation-server');
    expect(calls.single.name, 'sendConversationMessage');
    expect(calls.single.timeout, const Duration(seconds: 20));
    expect(calls.single.parameters['conversationId'], 'conversation-local');
    expect(calls.single.parameters['text'], 'Bonjour');
    expect(calls.single.parameters['attachments'], <Map<String, dynamic>>[
      attachment.toJson(),
    ]);
  });

  test('conserve l’identifiant local lorsque la réponse est vide', () async {
    responses['sendConversationMessage'] = <String, dynamic>{
      'conversationId': '   ',
    };
    expect(
      await ConversationService.sendMessage(conversationId: 'conversation-1'),
      'conversation-1',
    );
    expect(calls.single.parameters.containsKey('attachments'), isFalse);

    calls.clear();
    responses['sendConversationMessage'] = const <String, dynamic>{};
    expect(
      await ConversationService.sendMessage(conversationId: 'conversation-2'),
      'conversation-2',
    );
  });

  test('retourne une photo traitée et valide son résultat', () async {
    responses['processConversationAttachmentPhoto'] = <String, dynamic>{
      'storagePath': 'processed/photo.webp',
      'downloadUrl': 'https://cdn.test/photo.webp',
      'thumbnailUrl': 'https://cdn.test/thumb.webp',
      'mimeType': 'image/webp',
      'sizeBytes': 512,
    };

    final photo = await ConversationService.processConversationPhoto(
      conversationId: 'conversation-1',
      storagePath: 'raw/photo.jpg',
    );

    expect(photo.storagePath, 'processed/photo.webp');
    expect(photo.downloadUrl, 'https://cdn.test/photo.webp');
    expect(calls.single.name, 'processConversationAttachmentPhoto');
    expect(calls.single.timeout, const Duration(seconds: 60));
    expect(calls.single.parameters, <String, dynamic>{
      'conversationId': 'conversation-1',
      'storagePath': 'raw/photo.jpg',
    });
  });

  test('refuse une photo non traitée', () async {
    responses['processConversationAttachmentPhoto'] = <String, dynamic>{
      'storagePath': 'processed/photo.webp',
      'downloadUrl': ' ',
    };
    await expectLater(
      ConversationService.processConversationPhoto(
        conversationId: 'conversation-1',
        storagePath: 'raw/photo.jpg',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('route toutes les actions de gestion vers le callable attendu', () async {
    await ConversationService.markAsRead(conversationId: 'conversation-1');
    await ConversationService.archiveConversation(
      conversationId: 'conversation-1',
    );
    await ConversationService.unarchiveConversation(
      conversationId: 'conversation-1',
    );
    await ConversationService.blockConversation(
      conversationId: 'conversation-1',
    );
    await ConversationService.unblockConversation(
      conversationId: 'conversation-1',
    );
    await ConversationService.adminUnblockConversation(
      conversationId: 'conversation-1',
    );
    await ConversationService.deleteConversation(
      conversationId: 'conversation-1',
    );
    await ConversationService.deleteMessage(
      conversationId: 'conversation-1',
      messageId: 'message-1',
    );

    expect(
      calls.map((call) => call.name),
      <String>[
        'markConversationRead',
        'archiveConversation',
        'unarchiveConversation',
        'blockConversation',
        'unblockConversation',
        'adminUnblockConversation',
        'deleteConversation',
        'deleteConversationMessage',
      ],
    );
    expect(
      calls.map((call) => call.timeout),
      <Duration>[
        const Duration(seconds: 15),
        const Duration(seconds: 15),
        const Duration(seconds: 15),
        const Duration(seconds: 15),
        const Duration(seconds: 15),
        const Duration(seconds: 20),
        const Duration(seconds: 30),
        const Duration(seconds: 15),
      ],
    );
    for (final call in calls.take(7)) {
      expect(call.parameters, <String, dynamic>{
        'conversationId': 'conversation-1',
      });
    }
    expect(calls.last.parameters, <String, dynamic>{
      'conversationId': 'conversation-1',
      'messageId': 'message-1',
    });
  });
}
