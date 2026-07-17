import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/conversation_participants.dart';

void main() {
  group('conversation participant contracts', () {
    test('query contract remains canonical and Firestore-compatible', () {
      expect(conversationPrimaryParticipantField, 'participantIds');
      expect(conversationParticipantQueryFieldAliases, const ['participantIds']);
      expect(
        conversationParticipantFieldAliases,
        containsAll(<String>[
          'participantIds',
          'participants',
          'participant_ids',
          'userIds',
          'memberIds',
        ]),
      );
      expect(
        conversationParticipantMapAliases,
        containsAll(<String>[
          'participantNames',
          'participant_names',
          'unreadCount',
          'unread_count',
          'lastReadAt',
          'last_read_at',
          'archivedBy',
          'blockedBy',
        ]),
      );
    });
  });

  group('readConversationParticipantIdsFromCanonicalId', () {
    test('rejects empty and non canonical identifiers', () {
      expect(readConversationParticipantIdsFromCanonicalId(''), isEmpty);
      expect(readConversationParticipantIdsFromCanonicalId('thread_a__b'), isEmpty);
      expect(readConversationParticipantIdsFromCanonicalId(' offer_a__b '), isEmpty);
    });

    test('rejects incomplete offer identifiers', () {
      expect(readConversationParticipantIdsFromCanonicalId('offer_listing'), isEmpty);
      expect(readConversationParticipantIdsFromCanonicalId('offer_listing__user-a'), isEmpty);
      expect(readConversationParticipantIdsFromCanonicalId('offer___user-a'), isEmpty);
    });

    test('extracts, trims and sorts participant ids', () {
      expect(
        readConversationParticipantIdsFromCanonicalId(
          ' offer_listing-9__ user-z __user-a ',
        ),
        <String>['user-a', 'user-z'],
      );
    });

    test('keeps additional canonical participants', () {
      expect(
        readConversationParticipantIdsFromCanonicalId(
          'offer_listing__user-c__user-a__user-b',
        ),
        <String>['user-a', 'user-b', 'user-c'],
      );
    });
  });

  group('readConversationParticipants', () {
    test('returns an empty list for empty data', () {
      expect(readConversationParticipants(const <String, dynamic>{}), isEmpty);
    });

    test('reads every legacy list alias, trims and deduplicates', () {
      final participants = readConversationParticipants(<String, dynamic>{
        'participantIds': <dynamic>[' user-b ', 'user-a', ''],
        'participants': <dynamic>['user-c', 'user-a'],
        'participant_ids': <dynamic>['user-d'],
        'userIds': <dynamic>['user-e'],
        'memberIds': <dynamic>['user-f', 'user-b'],
      });

      expect(
        participants,
        <String>['user-a', 'user-b', 'user-c', 'user-d', 'user-e', 'user-f'],
      );
    });

    test('ignores list aliases whose value is not a list', () {
      expect(
        readConversationParticipants(<String, dynamic>{
          'participantIds': 'user-a',
          'participants': <String, dynamic>{'user-b': true},
        }),
        isEmpty,
      );
    });

    test('reads participant ids from every supported map alias', () {
      final participants = readConversationParticipants(<String, dynamic>{
        'participantNames': <String, dynamic>{'user-b': 'B'},
        'participant_names': <String, dynamic>{'user-a': 'A'},
        'unreadCount': <String, dynamic>{'user-c': 2},
        'unread_count': <String, dynamic>{'user-d': 1},
        'lastReadAt': <String, dynamic>{'user-e': 1},
        'last_read_at': <String, dynamic>{'user-f': 1},
        'archivedBy': <String, dynamic>{'user-g': true},
        'blockedBy': <String, dynamic>{'user-h': true},
      });

      expect(
        participants,
        <String>[
          'user-a',
          'user-b',
          'user-c',
          'user-d',
          'user-e',
          'user-f',
          'user-g',
          'user-h',
        ],
      );
    });

    test('ignores map aliases whose value is not a map', () {
      expect(
        readConversationParticipants(<String, dynamic>{
          'participantNames': <String>['user-a'],
          'unreadCount': 4,
          'archivedBy': true,
        }),
        isEmpty,
      );
    });

    test('combines document aliases and canonical id without duplicates', () {
      expect(
        readConversationParticipants(
          <String, dynamic>{
            'participantIds': <String>['user-b'],
            'participantNames': <String, String>{'user-c': 'C'},
          },
          conversationId: 'offer_listing__user-a__user-b',
        ),
        <String>['user-a', 'user-b', 'user-c'],
      );
    });

    test('converts non-string entries through their textual identifier', () {
      expect(
        readConversationParticipants(<String, dynamic>{
          'participantIds': <dynamic>[42, true, '  user-a  '],
        }),
        <String>['42', 'true', 'user-a'],
      );
    });
  });

  group('conversationIncludesUser', () {
    const data = <String, dynamic>{
      'participantIds': <String>['user-a'],
      'blockedBy': <String, bool>{'user-b': true},
    };

    test('rejects empty user ids', () {
      expect(conversationIncludesUser(data, ''), isFalse);
      expect(conversationIncludesUser(data, '   '), isFalse);
    });

    test('matches list and map aliases after trimming', () {
      expect(conversationIncludesUser(data, ' user-a '), isTrue);
      expect(conversationIncludesUser(data, 'user-b'), isTrue);
      expect(conversationIncludesUser(data, 'user-z'), isFalse);
    });

    test('matches a participant recovered from canonical conversation id', () {
      expect(
        conversationIncludesUser(
          const <String, dynamic>{},
          'user-z',
          conversationId: 'offer_listing__user-a__user-z',
        ),
        isTrue,
      );
    });
  });
}
