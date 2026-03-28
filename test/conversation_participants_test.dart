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
}