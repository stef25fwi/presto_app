import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/firestore_date_parser.dart';

class AdminConversationModel {
  final String id;
  final String shortId;
  final String contextId;
  final String contextTitle;
  final String category;
  final String region;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;
  final int messageCount;
  final String status;
  final int riskScore;
  final int reportCount;
  final bool adminWatchlisted;
  final bool hasAttachments;
  final bool hasUnread;

  const AdminConversationModel({
    required this.id,
    required this.shortId,
    required this.contextId,
    required this.contextTitle,
    required this.category,
    required this.region,
    required this.participantIds,
    required this.participantNames,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessageAt,
    required this.messageCount,
    required this.status,
    required this.riskScore,
    required this.reportCount,
    required this.adminWatchlisted,
    required this.hasAttachments,
    required this.hasUnread,
  });

  String get participantSummary {
    final names = participantNames.values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (names.isNotEmpty) {
      return names.join(' • ');
    }
    if (participantIds.isNotEmpty) {
      return participantIds.join(' • ');
    }
    return 'Participants inconnus';
  }

  factory AdminConversationModel.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return AdminConversationModel.fromData(doc.id, doc.data());
  }

  factory AdminConversationModel.fromData(
    String id,
    Map<String, dynamic> data,
  ) {
    final participantIds =
        ((data['participantIds'] as List?) ?? const <dynamic>[])
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false);
    final rawNames = data['participantNames'];
    final participantNames = <String, String>{};
    if (rawNames is Map) {
      for (final entry in rawNames.entries) {
        final key = entry.key.toString().trim();
        final value = entry.value.toString().trim();
        if (key.isEmpty || value.isEmpty) continue;
        participantNames[key] = value;
      }
    }
    final unreadCounts = data['unreadCount'] ?? data['unreadCounts'];
    final hasUnread = unreadCounts is Map &&
        unreadCounts.values.any((value) {
          if (value is num) return value > 0;
          return int.tryParse(value.toString()) != null &&
              int.parse(value.toString()) > 0;
        });
    final attachments = data['attachmentIds'];
    return AdminConversationModel(
      id: id,
      shortId: id.length <= 8 ? id : id.substring(0, 8),
      contextId:
          (data['contextId'] ?? data['listingId'] ?? data['offerId'] ?? '')
              .toString(),
      contextTitle: (data['contextTitle'] ??
              data['listingTitle'] ??
              data['offerTitle'] ??
              'Conversation sans titre')
          .toString(),
      category: (data['categoryId'] ?? data['category'] ?? 'Non catégorisée')
          .toString(),
      region: (data['region'] ?? 'Non renseignée').toString(),
      participantIds: participantIds,
      participantNames: participantNames,
      createdAt: parseFirestoreDateTime(data['createdAt']),
      updatedAt: parseFirestoreDateTime(data['updatedAt']),
      lastMessageAt: parseFirestoreDateTime(
        data['lastMessageAt'] ?? data['updatedAt'],
      ),
      messageCount: (data['messageCount'] is num)
          ? (data['messageCount'] as num).toInt()
          : int.tryParse('${data['messageCount'] ?? 0}') ?? 0,
      status: (data['status'] ?? 'active').toString(),
      riskScore: (data['riskScore'] is num)
          ? (data['riskScore'] as num).toInt()
          : int.tryParse('${data['riskScore'] ?? 0}') ?? 0,
      reportCount: (data['reportCount'] is num)
          ? (data['reportCount'] as num).toInt()
          : int.tryParse('${data['reportCount'] ?? 0}') ?? 0,
      adminWatchlisted: data['adminWatchlisted'] == true,
      hasAttachments: (attachments is List && attachments.isNotEmpty) ||
          data['lastMessageType'] == 'attachment',
      hasUnread: hasUnread,
    );
  }
}
