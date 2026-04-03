import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/conversation_summary.dart';
import 'package:presto_app/services/inbox_counts.dart';

void main() {
  test('lit le bon compteur selon le type demande', () {
    final inboxCounts = <String, dynamic>{
      'totalUnread': 9,
      'unreadMessages': 6,
      'unreadNotifications': 3,
    };

    expect(readInboxCount(inboxCounts), 9);
    expect(
      readInboxCount(inboxCounts, type: InboxCountType.unreadMessages),
      6,
    );
    expect(
      readInboxCount(inboxCounts, type: InboxCountType.unreadNotifications),
      3,
    );
  });

  test('retombe a zero si les valeurs sont absentes ou invalides', () {
    expect(readInboxCount(null), 0);
    expect(
      readInboxCount(
        <String, dynamic>{'unreadMessages': 'oops'},
        type: InboxCountType.unreadMessages,
      ),
      0,
    );
  });

  test('calcule les non lus visibles apres fusion des sources fallback', () {
    final fallbackSummary = ConversationSummary.fromMap(
      'conversation_1',
      <String, dynamic>{
        'offerTitle': 'Annonce test',
        'unreadCount': <String, dynamic>{
          'buyer_1': 2,
        },
      },
      assumedParticipants: const <String>['buyer_1'],
    );

    final liveSummary = ConversationSummary.fromMap(
      'conversation_1',
      <String, dynamic>{
        'participants': <String>['buyer_1', 'seller_1'],
        'participantNames': <String, dynamic>{
          'buyer_1': 'Acheteur',
          'seller_1': 'Vendeur',
        },
        'lastMessage': 'Bonjour',
        'messageCount': 1,
        'unreadCount': <String, dynamic>{
          'buyer_1': 3,
        },
      },
    );

    final archivedSummary = ConversationSummary.fromMap(
      'conversation_2',
      <String, dynamic>{
        'participants': <String>['buyer_1', 'seller_2'],
        'offerTitle': 'Archivee',
        'messageCount': 1,
        'unreadCount': <String, dynamic>{
          'buyer_1': 5,
        },
        'archivedBy': <String, dynamic>{
          'buyer_1': true,
        },
      },
    );

    expect(
      computeVisibleUnreadMessageCount(
        userId: 'buyer_1',
        conversationLists: <List<ConversationSummary>>[
          <ConversationSummary>[fallbackSummary],
          <ConversationSummary>[liveSummary, archivedSummary],
        ],
      ),
      3,
    );
  });
}
