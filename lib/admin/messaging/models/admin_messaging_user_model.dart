import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/firestore_date_parser.dart';

class AdminMessagingUserModel {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String region;
  final DateTime? createdAt;
  final DateTime? lastActivityAt;
  final int openConversations;
  final int messagesSent;
  final int messagesReceived;
  final int reportsReceived;
  final int reportsSent;
  final String messagingStatus;
  final int riskScore;
  final double responseRate;
  final double averageResponseHours;

  const AdminMessagingUserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.region,
    required this.createdAt,
    required this.lastActivityAt,
    required this.openConversations,
    required this.messagesSent,
    required this.messagesReceived,
    required this.reportsReceived,
    required this.reportsSent,
    required this.messagingStatus,
    required this.riskScore,
    required this.responseRate,
    required this.averageResponseHours,
  });

  factory AdminMessagingUserModel.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return AdminMessagingUserModel.fromData(uid: doc.id, data: doc.data());
  }

  factory AdminMessagingUserModel.fromData({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    return AdminMessagingUserModel(
      uid: uid,
      name:
          '${data['displayName'] ?? data['name'] ?? data['pseudo'] ?? 'Utilisateur'}',
      email: '${data['email'] ?? ''}',
      role: '${data['primaryRole'] ?? data['role'] ?? 'user'}',
      region: '${data['region'] ?? 'Non renseignée'}',
      createdAt: parseFirestoreDateTime(data['createdAt']),
      lastActivityAt: parseFirestoreDateTime(
        data['lastMessagingActivityAt'] ??
            data['updatedAt'] ??
            data['lastSeenAt'],
      ),
      openConversations: (data['messagingOpenConversations'] is num)
          ? (data['messagingOpenConversations'] as num).toInt()
          : 0,
      messagesSent: (data['messagesSent'] is num)
          ? (data['messagesSent'] as num).toInt()
          : 0,
      messagesReceived: (data['messagesReceived'] is num)
          ? (data['messagesReceived'] as num).toInt()
          : 0,
      reportsReceived: (data['messagingReportsReceived'] is num)
          ? (data['messagingReportsReceived'] as num).toInt()
          : 0,
      reportsSent: (data['messagingReportsSent'] is num)
          ? (data['messagingReportsSent'] as num).toInt()
          : 0,
      messagingStatus: '${data['messagingStatus'] ?? 'actif'}',
      riskScore: (data['messagingRiskScore'] is num)
          ? (data['messagingRiskScore'] as num).toInt()
          : 0,
      responseRate: (data['messagingResponseRate'] is num)
          ? (data['messagingResponseRate'] as num).toDouble()
          : 0,
      averageResponseHours: (data['averageResponseHours'] is num)
          ? (data['averageResponseHours'] as num).toDouble()
          : 0,
    );
  }
}
