import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/firestore_date_parser.dart';

class AdminAuditLogModel {
  final String id;
  final String adminId;
  final String adminEmail;
  final String adminRole;
  final String action;
  final String targetType;
  final String targetId;
  final String reason;
  final String riskLevel;
  final DateTime? createdAt;

  const AdminAuditLogModel({
    required this.id,
    required this.adminId,
    required this.adminEmail,
    required this.adminRole,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.riskLevel,
    required this.createdAt,
  });

  factory AdminAuditLogModel.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return AdminAuditLogModel(
      id: doc.id,
      adminId: '${data['adminId'] ?? ''}',
      adminEmail: '${data['adminEmail'] ?? ''}',
      adminRole: '${data['adminRole'] ?? ''}',
      action: '${data['action'] ?? ''}',
      targetType: '${data['targetType'] ?? ''}',
      targetId: '${data['targetId'] ?? ''}',
      reason: '${data['reason'] ?? ''}',
      riskLevel: '${data['riskLevel'] ?? 'normal'}',
      createdAt: parseFirestoreDateTime(data['createdAt']),
    );
  }
}
