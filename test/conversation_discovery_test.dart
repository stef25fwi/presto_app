import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/conversation_discovery.dart';

void main() {
  test('extrait l identifiant de conversation depuis un chemin de message', () {
    expect(
      conversationIdFromMessageDocumentPath(
        'conversations/offer_123__alice__bob/messages/msg_1',
      ),
      'offer_123__alice__bob',
    );
  });

  test('fusionne les identifiants de conversation sans doublons ni vides', () {
    expect(
      mergeUniqueConversationIds(<String?>[
        'conv_a',
        'conv_b',
        'conv_a',
        '',
        null,
        ' conv_c ',
      ]),
      <String>['conv_a', 'conv_b', 'conv_c'],
    );
  });
}
