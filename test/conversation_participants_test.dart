import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/conversation_participants.dart';

void main() {
  test('lit les participants depuis les listes et les maps legacy', () {
    final data = <String, dynamic>{
      'participantIds': <String>['alice'],
      'participant_names': <String, dynamic>{
        'bob': 'Bob',
      },
      'unread_count': <String, dynamic>{
        'carol': 1,
      },
    };

    expect(readConversationParticipants(data), <String>['alice', 'bob', 'carol']);
  });

  test('verifie explicitement la presence de l utilisateur courant', () {
    final data = <String, dynamic>{
      'participants': <String>['alice', 'bob'],
    };

    expect(conversationIncludesUser(data, 'alice'), isTrue);
    expect(conversationIncludesUser(data, 'carol'), isFalse);
  });

  test('recupere aussi les participants depuis l identifiant canonique', () {
    final data = <String, dynamic>{};

    expect(
      readConversationParticipants(
        data,
        conversationId: 'offer_offer_123__alice__bob',
      ),
      <String>['alice', 'bob'],
    );
    expect(
      conversationIncludesUser(
        data,
        'alice',
        conversationId: 'offer_offer_123__alice__bob',
      ),
      isTrue,
    );
  });

  test('ignore les identifiants non canoniques ou incomplets', () {
    expect(
      readConversationParticipantIdsFromCanonicalId('conversation_123'),
      isEmpty,
    );
    expect(
      readConversationParticipantIdsFromCanonicalId('offer_offer_123__alice'),
      isEmpty,
    );
  });
}