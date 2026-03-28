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
  var docs = const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscription;

  void emit() {
    final unreadMessages = docs.fold<int>(0, (total, doc) {
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

  subscription = FirebaseFirestore.instance
      .collection('conversations')
      .where(conversationPrimaryParticipantField, arrayContains: normalizedUserId)
      .snapshots()
      .listen(
        (snapshot) {
          docs = snapshot.docs;
          emit();
        },
        onError: (Object error, StackTrace stackTrace) {
          docs = const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          emit();
        },
      );

  controller.onCancel = () async {
    await subscription?.cancel();
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