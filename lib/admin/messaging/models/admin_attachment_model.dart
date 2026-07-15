import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/firestore_date_parser.dart';

class AdminAttachmentModel {
  final String id;
  final String conversationId;
  final String messageId;
  final String senderId;
  final String storagePath;
  final String fileType;
  final int fileSize;
  final String mimeType;
  final String moderationStatus;
  final int reportCount;
  final DateTime? createdAt;
  final DateTime? deletedAt;

  const AdminAttachmentModel({
    required this.id,
    required this.conversationId,
    required this.messageId,
    required this.senderId,
    required this.storagePath,
    required this.fileType,
    required this.fileSize,
    required this.mimeType,
    required this.moderationStatus,
    required this.reportCount,
    required this.createdAt,
    required this.deletedAt,
  });

  factory AdminAttachmentModel.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return AdminAttachmentModel.fromData(id: doc.id, data: doc.data());
  }

  factory AdminAttachmentModel.fromData({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return AdminAttachmentModel(
      id: id,
      conversationId: '${data['conversationId'] ?? ''}',
      messageId: '${data['messageId'] ?? ''}',
      senderId: '${data['senderId'] ?? ''}',
      storagePath: '${data['storagePath'] ?? ''}',
      fileType: '${data['fileType'] ?? 'other'}',
      fileSize: (data['fileSize'] is num)
          ? (data['fileSize'] as num).toInt()
          : int.tryParse('${data['fileSize'] ?? 0}') ?? 0,
      mimeType: '${data['mimeType'] ?? 'application/octet-stream'}',
      moderationStatus: '${data['moderationStatus'] ?? 'unknown'}',
      reportCount: (data['reportCount'] is num)
          ? (data['reportCount'] as num).toInt()
          : 0,
      createdAt: parseFirestoreDateTime(data['createdAt']),
      deletedAt: parseFirestoreDateTime(data['deletedAt']),
    );
  }
}
