import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/firestore_date_parser.dart';

class AdminNotificationLogModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String routeName;
  final String conversationId;
  final String type;
  final String deliveryStatus;
  final DateTime? createdAt;

  const AdminNotificationLogModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.routeName,
    required this.conversationId,
    required this.type,
    required this.deliveryStatus,
    required this.createdAt,
  });

  bool get isMessagingRelated =>
      conversationId.trim().isNotEmpty || routeName.contains('/messages');

  factory AdminNotificationLogModel.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return AdminNotificationLogModel.fromData(id: doc.id, data: doc.data());
  }

  factory AdminNotificationLogModel.fromData({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return AdminNotificationLogModel(
      id: id,
      userId: '${data['userId'] ?? ''}',
      title: '${data['title'] ?? ''}',
      body: '${data['message'] ?? data['body'] ?? ''}',
      routeName: '${data['routeName'] ?? ''}',
      conversationId: '${data['conversationId'] ?? ''}',
      type: '${data['type'] ?? 'notification'}',
      deliveryStatus:
          '${data['deliveryStatus'] ?? data['status'] ?? 'unknown'}',
      createdAt: parseFirestoreDateTime(data['createdAt']),
    );
  }
}
