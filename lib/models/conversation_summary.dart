import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/conversation_participants.dart';
import '../services/firestore_date_parser.dart';

class ConversationSummary {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final String otherUserName;
  final String offerId;
  final String offerTitle;
  final String lastMessage;
  final String lastSenderId;
  final String lastSenderName;
  final Map<String, int> unreadCount;
  final int messageCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;
  final String status;
  final Map<String, bool> archivedBy;
  final Map<String, bool> blockedBy;

  const ConversationSummary({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.otherUserName,
    required this.offerId,
    required this.offerTitle,
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastSenderName,
    required this.unreadCount,
    required this.messageCount,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessageAt,
    required this.status,
    required this.archivedBy,
    required this.blockedBy,
  });

  factory ConversationSummary.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return ConversationSummary.fromMap(snapshot.id, snapshot.data());
  }

  factory ConversationSummary.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return ConversationSummary(
      id: id,
      participants: readConversationParticipants(data),
      participantNames: _readStringMap(
        data,
        const ['participantNames', 'participant_names'],
      ),
      otherUserName: _readString(
        data,
        const ['otherUserName', 'other_user_name'],
      ),
      offerId: _readString(data, const ['offerId', 'offer_id']),
      offerTitle: _readString(data, const ['offerTitle', 'offer_title']),
      lastMessage: _readString(data, const ['lastMessage', 'last_message']),
      lastSenderId: _readString(data, const ['lastSenderId', 'last_sender_id']),
      lastSenderName: _readString(
        data,
        const ['lastSenderName', 'last_sender_name'],
      ),
      unreadCount: _readIntMap(data, const ['unreadCount', 'unread_count']),
      messageCount: _readMessageCount(data),
      createdAt: parseFirestoreDateTime(data['createdAt'] ?? data['created_at']),
      updatedAt: parseFirestoreDateTime(data['updatedAt'] ?? data['updated_at']),
      lastMessageAt: parseFirestoreDateTime(
        data['lastMessageAt'] ?? data['last_message_at'],
      ),
      status: _readString(data, const ['status']),
      archivedBy: _readBoolMap(data, const ['archivedBy']),
      blockedBy: _readBoolMap(data, const ['blockedBy']),
    );
  }

  bool includesUser(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return false;
    return participants.contains(normalizedUserId);
  }

  int unreadForUser(String userId) {
    return unreadCount[userId.trim()] ?? 0;
  }

  bool isArchivedForUser(String userId) {
    return archivedBy[userId.trim()] == true;
  }

  bool isBlockedForUser(String userId) {
    return blockedBy[userId.trim()] == true;
  }

  bool get isBlocked {
    return blockedBy.values.any((value) => value) ||
        status.trim().toLowerCase() == 'closed';
  }

  bool get hasRenderableContent {
    return messageCount > 0 || lastMessage.isNotEmpty || lastMessageAt != null;
  }

  DateTime? get sortDate {
    return lastMessageAt ?? updatedAt ?? createdAt;
  }

  String titleFor(String userId) {
    for (final entry in participantNames.entries) {
      if (entry.key == userId) continue;
      final value = entry.value.trim();
      if (value.isNotEmpty) return value;
    }

    final candidates = [otherUserName, offerTitle];
    for (final candidate in candidates) {
      final value = candidate.trim();
      if (value.isNotEmpty) return value;
    }
    return 'Conversation';
  }

  String previewFor(String userId) {
    if (lastMessage.isNotEmpty) {
      if (lastSenderId == userId) {
        return 'Vous : $lastMessage';
      }
      return lastMessage;
    }

    if (messageCount > 0) {
      return 'Messages sans apercu';
    }

    if (offerTitle.isNotEmpty) {
      return offerTitle;
    }

    return 'Touchez pour ouvrir la conversation';
  }

  bool matchesQuery(String userId, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    return [
      titleFor(userId),
      previewFor(userId),
      offerTitle,
      lastMessage,
      lastSenderName,
    ].join(' ').toLowerCase().contains(normalizedQuery);
  }

  static String _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (!data.containsKey(key)) continue;
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static Map<String, String> _readStringMap(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final raw = data[key];
      if (raw is! Map) continue;

      final result = <String, String>{};
      for (final entry in raw.entries) {
        final mapKey = entry.key.toString().trim();
        final mapValue = entry.value?.toString().trim() ?? '';
        if (mapKey.isEmpty || mapValue.isEmpty) continue;
        result[mapKey] = mapValue;
      }
      return result;
    }
    return const <String, String>{};
  }

  static Map<String, int> _readIntMap(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final raw = data[key];
      if (raw is! Map) continue;

      final result = <String, int>{};
      for (final entry in raw.entries) {
        final mapKey = entry.key.toString().trim();
        final value = entry.value;
        final intValue = value is num ? value.toInt() : int.tryParse('$value');
        if (mapKey.isEmpty || intValue == null) continue;
        result[mapKey] = intValue;
      }
      return result;
    }
    return const <String, int>{};
  }

  static Map<String, bool> _readBoolMap(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final raw = data[key];
      if (raw is! Map) continue;

      final result = <String, bool>{};
      for (final entry in raw.entries) {
        final mapKey = entry.key.toString().trim();
        if (mapKey.isEmpty) continue;
        result[mapKey] = entry.value == true;
      }
      return result;
    }
    return const <String, bool>{};
  }

  static int _readMessageCount(Map<String, dynamic> data) {
    final raw = data['messageCount'] ?? data['message_count'];
    if (raw is num) return raw.toInt();
    final parsed = int.tryParse('${raw ?? ''}');
    if (parsed != null) return parsed;
    final lastMessage = _readString(data, const ['lastMessage', 'last_message']);
    return lastMessage.isNotEmpty ? 1 : 0;
  }
}