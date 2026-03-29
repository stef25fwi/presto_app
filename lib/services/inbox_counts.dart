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
  final conversationsBySource = <String, List<ConversationSummary>>{};
  final querySubscriptions =
      <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      notificationsSubscription;
  const notificationsFallbackSource = '__notifications__';

  void emit() {
    final mergedConversations = _mergeConversationSummaries(
      conversationsBySource.values,
    );
    final unreadMessages = mergedConversations.fold<int>(0, (total, conversation) {
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

  void listenConversationField(String participantField) {
    querySubscriptions.remove(participantField)?.cancel();
    querySubscriptions[participantField] = FirebaseFirestore.instance
        .collection('conversations')
        .where(participantField, arrayContains: normalizedUserId)
        .snapshots()
        .listen(
        (snapshot) {
          conversationsBySource[participantField] = snapshot.docs
              .map(ConversationSummary.fromFirestore)
              .toList(growable: false);
          emit();
        },
        onError: (Object error, StackTrace stackTrace) {
          conversationsBySource[participantField] = const <ConversationSummary>[];
          emit();
        },
      );
  }

  Future<void> refreshNotificationsFallback(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> notificationDocs,
  ) async {
    final conversationIds = <String>[];
    final seenConversationIds = <String>{};
    for (final notificationDoc in notificationDocs) {
      final conversationId = _notificationConversationId(notificationDoc.data());
      if (conversationId == null || !seenConversationIds.add(conversationId)) {
        continue;
      }
      conversationIds.add(conversationId);
    }

    if (conversationIds.isEmpty) {
      conversationsBySource[notificationsFallbackSource] =
          const <ConversationSummary>[];
      emit();
      return;
    }

    try {
      final snapshots = await Future.wait(
        conversationIds.map(
          (conversationId) => FirebaseFirestore.instance
              .collection('conversations')
              .doc(conversationId)
              .get(),
        ),
      );

      if (controller.isClosed) return;

      conversationsBySource[notificationsFallbackSource] = snapshots
          .where((snapshot) => snapshot.exists)
          .map((snapshot) {
            final data = snapshot.data();
            if (data == null) return null;
            return ConversationSummary.fromMap(
              snapshot.id,
              Map<String, dynamic>.from(data),
            );
          })
          .whereType<ConversationSummary>()
          .where((conversation) => conversation.includesUser(normalizedUserId))
          .toList(growable: false);
      emit();
    } catch (_) {
      conversationsBySource[notificationsFallbackSource] =
          const <ConversationSummary>[];
      emit();
    }
  }

  for (final participantField in conversationParticipantQueryFieldAliases) {
    listenConversationField(participantField);
  }

  notificationsSubscription = FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: normalizedUserId)
      .orderBy('createdAt', descending: true)
      .limit(60)
      .snapshots()
      .listen(
        (snapshot) {
          unawaited(refreshNotificationsFallback(snapshot.docs));
        },
        onError: (Object error, StackTrace stackTrace) {
          conversationsBySource[notificationsFallbackSource] =
              const <ConversationSummary>[];
          emit();
        },
      );

  controller.onCancel = () async {
    await notificationsSubscription?.cancel();
    for (final subscription in querySubscriptions.values) {
      await subscription.cancel();
    }
  };

  return controller.stream;
}

String? _notificationConversationId(Map<String, dynamic> data) {
  final directValue = (data['conversationId'] ?? data['conversation_id'] ?? '')
      .toString()
      .trim();
  if (directValue.isNotEmpty) {
    return directValue;
  }

  final routeName = (data['routeName'] ?? data['route_name'] ?? '')
      .toString()
      .trim();
  if (!routeName.startsWith('/messages/')) {
    return null;
  }

  final segments = routeName.split('/');
  if (segments.length < 3) {
    return null;
  }

  final conversationId = Uri.decodeComponent(segments[2]).trim();
  return conversationId.isEmpty ? null : conversationId;
}

List<ConversationSummary> _mergeConversationSummaries(
  Iterable<List<ConversationSummary>> conversationLists,
) {
  final byId = <String, ConversationSummary>{};
  for (final conversations in conversationLists) {
    for (final conversation in conversations) {
      byId.putIfAbsent(conversation.id, () => conversation);
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