import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/conversation_summary.dart';
import 'conversation_discovery.dart';
import 'conversation_participants.dart';

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
      .snapshots()
      .map((snapshot) {
    final inboxCounts =
        (snapshot.data()?['inboxCounts'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
    return readInboxCount(inboxCounts, type: type);
  });
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
  const startedMessageFallbackSourcePrefix = '__started_messages__:';
  const sentMessageFieldAliases = <String>['senderId', 'sender_id'];
  const notificationsFallbackLiveLimit = 60;
  const notificationsFallbackMaxPages = 4;
  const startedMessageFallbackLiveLimit = 80;
  const startedMessageFallbackMaxPages = 4;

  void emit() {
    final unreadMessages = computeVisibleUnreadMessageCount(
      userId: normalizedUserId,
      conversationLists: conversationsBySource.values,
    );

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

  Future<List<String>> collectPagedConversationIds({
    required Iterable<String?> initialConversationIds,
    required Query<Map<String, dynamic>> baseQuery,
    required QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc,
    required int maxPages,
    required int pageSize,
    required String? Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
        extractConversationId,
  }) async {
    var mergedConversationIds = mergeConversationIdPages(
      initialConversationIds,
    );
    if (lastDoc == null || maxPages <= 1) {
      return mergedConversationIds;
    }

    var cursor = lastDoc;
    var loadedPages = 1;
    while (loadedPages < maxPages) {
      final snapshot =
          await baseQuery.startAfterDocument(cursor).limit(pageSize).get();

      if (snapshot.docs.isEmpty) {
        break;
      }

      mergedConversationIds = mergeConversationIdPages(
        mergedConversationIds,
        additionalPages: <Iterable<String?>>[
          snapshot.docs.map(extractConversationId),
        ],
      );

      loadedPages += 1;
      if (snapshot.docs.length < pageSize) {
        break;
      }
      cursor = snapshot.docs.last;
    }

    return mergedConversationIds;
  }

  Future<void> refreshConversationFallback(
    String source,
    Iterable<String?> rawConversationIds,
  ) async {
    final conversationIds = mergeUniqueConversationIds(rawConversationIds);
    if (conversationIds.isEmpty) {
      conversationsBySource[source] = const <ConversationSummary>[];
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

      conversationsBySource[source] = snapshots
          .where((snapshot) => snapshot.exists)
          .map((snapshot) {
            final data = snapshot.data();
            if (data == null) return null;
            return ConversationSummary.fromMap(
              snapshot.id,
              Map<String, dynamic>.from(data),
              assumedParticipants: <String>[normalizedUserId],
            );
          })
          .whereType<ConversationSummary>()
          .where((conversation) => conversation.includesUser(normalizedUserId))
          .toList(growable: false);
      emit();
    } catch (_) {
      conversationsBySource[source] = const <ConversationSummary>[];
      emit();
    }
  }

  Future<void> refreshNotificationsFallback(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> notificationDocs,
  ) async {
    final conversationIds = notificationDocs.length <
            notificationsFallbackLiveLimit
        ? mergeUniqueConversationIds(
            notificationDocs.map(
              (notificationDoc) =>
                  _notificationConversationId(notificationDoc.data()),
            ),
          )
        : await collectPagedConversationIds(
            initialConversationIds: notificationDocs.map(
              (notificationDoc) =>
                  _notificationConversationId(notificationDoc.data()),
            ),
            baseQuery: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: normalizedUserId)
                .orderBy('createdAt', descending: true),
            lastDoc: notificationDocs.isEmpty ? null : notificationDocs.last,
            maxPages: notificationsFallbackMaxPages,
            pageSize: notificationsFallbackLiveLimit,
            extractConversationId: (notificationDoc) =>
                _notificationConversationId(notificationDoc.data()),
          );

    await refreshConversationFallback(
      notificationsFallbackSource,
      conversationIds,
    );
  }

  Future<void> refreshStartedMessagesFallback(
    String senderField,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> messageDocs,
  ) async {
    final source = '$startedMessageFallbackSourcePrefix$senderField';
    final baseQuery = FirebaseFirestore.instance
        .collectionGroup('messages')
        .where(senderField, isEqualTo: normalizedUserId)
        .orderBy(FieldPath.documentId);

    final conversationIds = messageDocs.length < startedMessageFallbackLiveLimit
        ? mergeUniqueConversationIds(
            messageDocs.map(
              (messageDoc) => conversationIdFromMessageDocumentPath(
                  messageDoc.reference.path),
            ),
          )
        : await collectPagedConversationIds(
            initialConversationIds: messageDocs.map(
              (messageDoc) => conversationIdFromMessageDocumentPath(
                  messageDoc.reference.path),
            ),
            baseQuery: baseQuery,
            lastDoc: messageDocs.isEmpty ? null : messageDocs.last,
            maxPages: startedMessageFallbackMaxPages,
            pageSize: startedMessageFallbackLiveLimit,
            extractConversationId: (messageDoc) =>
                conversationIdFromMessageDocumentPath(
                    messageDoc.reference.path),
          );

    await refreshConversationFallback(source, conversationIds);
  }

  void listenStartedMessagesField(String senderField) {
    final source = '$startedMessageFallbackSourcePrefix$senderField';
    querySubscriptions.remove(source)?.cancel();
    querySubscriptions[source] = FirebaseFirestore.instance
        .collectionGroup('messages')
        .where(senderField, isEqualTo: normalizedUserId)
        .orderBy(FieldPath.documentId)
        .limit(startedMessageFallbackLiveLimit)
        .snapshots()
        .listen(
      (snapshot) {
        unawaited(refreshStartedMessagesFallback(senderField, snapshot.docs));
      },
      onError: (Object error, StackTrace stackTrace) {
        conversationsBySource[source] = const <ConversationSummary>[];
        emit();
      },
    );
  }

  for (final participantField in conversationParticipantQueryFieldAliases) {
    listenConversationField(participantField);
  }
  for (final senderField in sentMessageFieldAliases) {
    listenStartedMessagesField(senderField);
  }

  notificationsSubscription = FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: normalizedUserId)
      .orderBy('createdAt', descending: true)
      .limit(notificationsFallbackLiveLimit)
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

  final routeName =
      (data['routeName'] ?? data['route_name'] ?? '').toString().trim();
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
