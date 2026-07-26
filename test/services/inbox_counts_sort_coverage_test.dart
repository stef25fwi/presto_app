import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/conversation_summary.dart';
import 'package:presto_app/services/inbox_counts.dart';

ConversationSummary summary({
  required String id,
  required int unread,
  DateTime? date,
}) {
  return ConversationSummary(
    id: id,
    participants: const <String>['user-1', 'user-2'],
    participantNames: const <String, String>{},
    otherUserName: 'Utilisateur',
    offerId: '',
    offerTitle: '',
    lastMessage: 'Message',
    lastSenderId: 'user-2',
    lastSenderName: 'Utilisateur',
    unreadCount: <String, int>{'user-1': unread},
    messageCount: 1,
    createdAt: date,
    updatedAt: null,
    lastMessageAt: null,
    status: 'active',
    archivedBy: const <String, bool>{},
    deletedBy: const <String, bool>{},
    blockedBy: const <String, bool>{},
  );
}

void main() {
  test('retourne zéro pour un utilisateur vide', () {
    expect(
      computeVisibleUnreadMessageCount(
        userId: '   ',
        conversationLists: const <List<ConversationSummary>>[],
      ),
      0,
    );
  });

  test('couvre toutes les branches du tri avec dates nulles', () {
    final dated = summary(
      id: 'dated',
      unread: 1,
      date: DateTime.utc(2026, 7, 26),
    );
    final nullA = summary(id: 'a-null', unread: 2);
    final nullB = summary(id: 'b-null', unread: 3);

    expect(
      computeVisibleUnreadMessageCount(
        userId: 'user-1',
        conversationLists: <List<ConversationSummary>>[
          <ConversationSummary>[nullA, dated, nullB],
        ],
      ),
      6,
    );

    expect(
      computeVisibleUnreadMessageCount(
        userId: 'user-1',
        conversationLists: <List<ConversationSummary>>[
          <ConversationSummary>[dated, nullB, nullA],
        ],
      ),
      6,
    );
  });
}
