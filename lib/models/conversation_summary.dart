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
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot, {
    List<String> assumedParticipants = const <String>[],
  }) {
    return ConversationSummary.fromMap(
      snapshot.id,
      snapshot.data(),
      assumedParticipants: assumedParticipants,
    );
  }

  factory ConversationSummary.fromMap(
    String id,
    Map<String, dynamic> data, {
    List<String> assumedParticipants = const <String>[],
  }) {
    return ConversationSummary(
      id: id,
      participants: _mergeParticipants(
        readConversationParticipants(data, conversationId: id),
        assumedParticipants,
      ),
      participantNames: _readStringMap(
        data,
        const ['participantNames', 'participant_names'],
      ),
      otherUserName: _readString(
        data,
        const ['otherUserName', 'other_user_name'],
      ),
      offerId: _readString(data, const ['listingId', 'offerId', 'offer_id']),
      offerTitle: _readString(
        data,
        const ['listingTitle', 'offerTitle', 'offer_title'],
      ),
      lastMessage: _readString(data, const ['lastMessage', 'last_message']),
      lastSenderId: _readString(data, const ['lastSenderId', 'last_sender_id']),
      lastSenderName: _readString(
        data,
        const ['lastSenderName', 'last_sender_name'],
      ),
      unreadCount: _readIntMap(data, const ['unreadCount', 'unread_count']),
      messageCount: _readMessageCount(data),
      createdAt:
          parseFirestoreDateTime(data['createdAt'] ?? data['created_at']),
      updatedAt:
          parseFirestoreDateTime(data['updatedAt'] ?? data['updated_at']),
      lastMessageAt: parseFirestoreDateTime(
        data['lastMessageAt'] ?? data['last_message_at'],
      ),
      status: _readString(data, const ['status']),
      archivedBy: _readBoolMap(data, const ['archivedBy']),
      blockedBy: _readBoolMap(data, const ['blockedBy']),
    );
  }

  ConversationSummary mergeWith(ConversationSummary other) {
    if (id != other.id) {
      throw ArgumentError.value(
          other.id, 'other.id', 'conversation ids must match');
    }

    final latest = _latestSummary(this, other);
    final fallback = identical(latest, this) ? other : this;

    return ConversationSummary(
      id: id,
      participants: _mergeParticipants(participants, other.participants),
      participantNames:
          _mergeStringMaps(participantNames, other.participantNames),
      otherUserName: _pickPreferredString(other.otherUserName, otherUserName),
      offerId: _pickPreferredString(other.offerId, offerId),
      offerTitle: _pickPreferredString(other.offerTitle, offerTitle),
      lastMessage:
          _pickPreferredString(latest.lastMessage, fallback.lastMessage),
      lastSenderId:
          _pickPreferredString(latest.lastSenderId, fallback.lastSenderId),
      lastSenderName:
          _pickPreferredString(latest.lastSenderName, fallback.lastSenderName),
      unreadCount: _mergeIntMaps(unreadCount, other.unreadCount),
      messageCount:
          messageCount > other.messageCount ? messageCount : other.messageCount,
      createdAt: _earliestDateTime(createdAt, other.createdAt),
      updatedAt: _latestDateTime(updatedAt, other.updatedAt),
      lastMessageAt: _latestDateTime(lastMessageAt, other.lastMessageAt),
      status: _pickPreferredString(other.status, status),
      archivedBy: _mergeBoolMaps(archivedBy, other.archivedBy),
      blockedBy: _mergeBoolMaps(blockedBy, other.blockedBy),
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
    return blockedBy.values.any((value) => value);
  }

  bool get hasRenderableContent {
    // A conversation that is correctly attached to the user should stay visible
    // even if preview metadata is still sparse or partially backfilled.
    return messageCount > 0 ||
        lastMessage.isNotEmpty ||
        lastMessageAt != null ||
        offerTitle.trim().isNotEmpty ||
        otherUserName.trim().isNotEmpty ||
        participants.isNotEmpty ||
        id.trim().isNotEmpty;
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

    if (participants
        .any((participant) => participant.trim() != userId.trim())) {
      return 'Conversation en cours';
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

    if (participants.isNotEmpty || id.trim().isNotEmpty) {
      return 'Touchez pour ouvrir cette conversation';
    }

    return 'Conversation en attente de synchronisation';
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
    final lastMessage =
        _readString(data, const ['lastMessage', 'last_message']);
    return lastMessage.isNotEmpty ? 1 : 0;
  }

  static List<String> _mergeParticipants(
    Iterable<String> primary,
    Iterable<String> secondary,
  ) {
    final merged = <String>{
      ...primary
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty),
      ...secondary
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty),
    }.toList(growable: false)
      ..sort();
    return merged;
  }

  static Map<String, String> _mergeStringMaps(
    Map<String, String> primary,
    Map<String, String> secondary,
  ) {
    final merged = <String, String>{...primary};
    for (final entry in secondary.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (key.isEmpty || value.isEmpty) continue;
      merged[key] = value;
    }
    return Map<String, String>.unmodifiable(merged);
  }

  static Map<String, int> _mergeIntMaps(
    Map<String, int> primary,
    Map<String, int> secondary,
  ) {
    final merged = <String, int>{...primary};
    for (final entry in secondary.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      final currentValue = merged[key] ?? 0;
      if (entry.value > currentValue) {
        merged[key] = entry.value;
      }
    }
    return Map<String, int>.unmodifiable(merged);
  }

  static Map<String, bool> _mergeBoolMaps(
    Map<String, bool> primary,
    Map<String, bool> secondary,
  ) {
    final merged = <String, bool>{...primary};
    for (final entry in secondary.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      merged[key] = (merged[key] == true) || entry.value;
    }
    return Map<String, bool>.unmodifiable(merged);
  }

  static String _pickPreferredString(String primary, String fallback) {
    final normalizedPrimary = primary.trim();
    if (normalizedPrimary.isNotEmpty) return normalizedPrimary;
    return fallback.trim();
  }

  static DateTime? _latestDateTime(DateTime? left, DateTime? right) {
    if (left == null) return right;
    if (right == null) return left;
    return left.isAfter(right) ? left : right;
  }

  static DateTime? _earliestDateTime(DateTime? left, DateTime? right) {
    if (left == null) return right;
    if (right == null) return left;
    return left.isBefore(right) ? left : right;
  }

  static ConversationSummary _latestSummary(
    ConversationSummary left,
    ConversationSummary right,
  ) {
    final leftDate = left.sortDate;
    final rightDate = right.sortDate;
    if (leftDate == null) return right;
    if (rightDate == null) return left;
    return rightDate.isAfter(leftDate) ? right : left;
  }
}
