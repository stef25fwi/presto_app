import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/conversation_summary.dart';

enum InboxCountType {
  totalUnread,
  unreadMessages,
  unreadNotifications,
}

Stream<int> streamInboxCount({
  required String userId,
  InboxCountType type = InboxCountType.totalUnread,
}) {
  final normalizedUserId = userId.trim();
  if (normalizedUserId.isEmpty) {
    return Stream<int>.value(0);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(normalizedUserId)
      .collection('metadata')
      .doc('inbox')
      .snapshots()
      .map((snapshot) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final inboxCounts = (data['inboxCounts'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return readInboxCount(inboxCounts, type: type);
  }).asBroadcastStream();
}

List<ConversationSummary> _mergeConversationSummaries(
  Iterable<List<ConversationSummary>> conversationLists,
) {
  final byId = <String, ConversationSummary>{};
  for (final conversations in conversationLists) {
    for (final conversation in conversations) {
      final existing = byId[conversation.id];
      byId[conversation.id] =
          existing == null ? conversation : existing.mergeWith(conversation);
    }
  }

  final merged = byId.values.toList(growable: false);
  merged.sort((left, right) {
    final rightDate = right.sortDate;
    final leftDate = left.sortDate;
    if (leftDate == null && rightDate == null) {
      return right.id.compareTo(left.id);
    }
    if (leftDate == null) return 1;
    if (rightDate == null) return -1;
    return rightDate.compareTo(leftDate);
  });
  return merged;
}

int computeVisibleUnreadMessageCount({
  required String userId,
  required Iterable<List<ConversationSummary>> conversationLists,
}) {
  final normalizedUserId = userId.trim();
  if (normalizedUserId.isEmpty) return 0;

  final mergedConversations = _mergeConversationSummaries(conversationLists);
  return mergedConversations.fold<int>(0, (total, conversation) {
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
