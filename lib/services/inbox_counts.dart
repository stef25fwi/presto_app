import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/conversation_summary.dart';
import 'conversation_participants.dart';

enum InboxCountType {
  totalUnread,
  unreadMessages,
  unreadNotifications,
}

Stream<int> streamVisibleUnreadMessageCount({required String userId}) {
  final normalizedUserId = userId.trim();
  if (normalizedUserId.isEmpty) {
    return Stream<int>.value(0);
  }

  final controller = StreamController<int>();
  final docsByField =
      <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
  final subscriptions = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

  void emit() {
    final mergedDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final field in conversationParticipantQueryFieldAliases) {
      for (final doc in docsByField[field] ??
          const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
        mergedDocs.putIfAbsent(doc.id, () => doc);
      }
    }

    final unreadMessages = mergedDocs.values.fold<int>(0, (total, doc) {
      final conversation = ConversationSummary.fromFirestore(doc);
      if (!conversation.includesUser(normalizedUserId)) {
        return total;
      }
      if (conversation.isArchivedForUser(normalizedUserId)) {
        return total;
      }
      if (!conversation.hasRenderableContent) {
        return total;
      }
      return total + conversation.unreadForUser(normalizedUserId);
    });

    if (!controller.isClosed) {
      controller.add(unreadMessages);
    }
  }

  for (final field in conversationParticipantQueryFieldAliases) {
    subscriptions.add(
      FirebaseFirestore.instance
          .collection('conversations')
          .where(field, arrayContains: normalizedUserId)
          .snapshots()
          .listen(
            (snapshot) {
              docsByField[field] = snapshot.docs;
              emit();
            },
            onError: (Object error, StackTrace stackTrace) {
              docsByField[field] = const [];
              emit();
            },
          ),
    );
  }

  controller.onCancel = () async {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  };

  return controller.stream;
}

int readInboxCount(
  Map<String, dynamic>? inboxCounts, {
  InboxCountType type = InboxCountType.totalUnread,
}) {
  final data = inboxCounts ?? const <String, dynamic>{};

  switch (type) {
    case InboxCountType.totalUnread:
      return _readCount(data['totalUnread']);
    case InboxCountType.unreadMessages:
      return _readCount(data['unreadMessages']);
    case InboxCountType.unreadNotifications:
      return _readCount(data['unreadNotifications']);
  }
}

int _readCount(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}