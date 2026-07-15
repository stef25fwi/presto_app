import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/firestore_date_parser.dart';

class AdminMessageReportModel {
  final String id;
  final String conversationId;
  final String messageId;
  final String reportedBy;
  final String reportedUserId;
  final String reason;
  final String description;
  final String priority;
  final String status;
  final String assignedTo;
  final String adminDecision;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  const AdminMessageReportModel({
    required this.id,
    required this.conversationId,
    required this.messageId,
    required this.reportedBy,
    required this.reportedUserId,
    required this.reason,
    required this.description,
    required this.priority,
    required this.status,
    required this.assignedTo,
    required this.adminDecision,
    required this.createdAt,
    required this.resolvedAt,
  });

  factory AdminMessageReportModel.fromData({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return AdminMessageReportModel(
      id: id,
      conversationId: '${data['conversationId'] ?? ''}',
      messageId: '${data['messageId'] ?? ''}',
      reportedBy: '${data['reportedBy'] ?? ''}',
      reportedUserId: '${data['reportedUserId'] ?? ''}',
      reason: '${data['reason'] ?? 'autre'}',
      description: '${data['description'] ?? ''}',
      priority: '${data['priority'] ?? 'moyenne'}',
      status: '${data['status'] ?? 'nouveau'}',
      assignedTo: '${data['assignedTo'] ?? ''}',
      adminDecision: '${data['adminDecision'] ?? ''}',
      createdAt: parseFirestoreDateTime(data['createdAt']),
      resolvedAt: parseFirestoreDateTime(data['resolvedAt']),
    );
  }

  factory AdminMessageReportModel.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return AdminMessageReportModel.fromData(id: doc.id, data: doc.data());
  }
}
