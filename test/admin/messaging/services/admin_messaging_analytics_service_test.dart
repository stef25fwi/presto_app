import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/models/admin_attachment_model.dart';
import 'package:presto_app/admin/messaging/models/admin_conversation_model.dart';
import 'package:presto_app/admin/messaging/models/admin_message_report_model.dart';
import 'package:presto_app/admin/messaging/models/admin_messaging_user_model.dart';
import 'package:presto_app/admin/messaging/models/admin_notification_log_model.dart';
import 'package:presto_app/admin/messaging/services/admin_messaging_analytics_service.dart';

void main() {
  group('AdminMessagingAnalyticsSnapshot', () {
    test('fromMap parse nombres, chaînes, date et métadonnées', () {
      final generatedAt = DateTime(2026, 7, 15, 12);
      final snapshot = AdminMessagingAnalyticsSnapshot.fromMap(
        <String, dynamic>{
          'totalConversations': '12',
          'activeToday': 4.9,
          'totalMessages': '90',
          'unansweredConversations': '2',
          'reportedConversations': 3,
          'blockedUsers': '1',
          'attachmentsCount': 8,
          'storageBytes': '4096',
          'activeUsers': 7,
          'watchlistedConversations': '2',
          'criticalRiskConversations': 1,
          'pendingReports': '2',
          'resolvedReports': 1,
          'averageResponseHours': '3.5',
          'providerResponseRate': 82,
          'pushSentCount': '10',
          'pushDeliveredCount': 8,
          'pushFailedCount': '2',
          'generatedAt': generatedAt,
          'source': 'scheduled',
          'windowHours': '24',
          'sampledNotifications': 50.8,
        },
      );

      expect(snapshot.totalConversations, 12);
      expect(snapshot.activeToday, 4);
      expect(snapshot.totalMessages, 90);
      expect(snapshot.unansweredConversations, 2);
      expect(snapshot.reportedConversations, 3);
      expect(snapshot.blockedUsers, 1);
      expect(snapshot.attachmentsCount, 8);
      expect(snapshot.storageBytes, 4096);
      expect(snapshot.activeUsers, 7);
      expect(snapshot.watchlistedConversations, 2);
      expect(snapshot.criticalRiskConversations, 1);
      expect(snapshot.pendingReports, 2);
      expect(snapshot.resolvedReports, 1);
      expect(snapshot.averageResponseHours, 3.5);
      expect(snapshot.providerResponseRate, 82);
      expect(snapshot.pushSentCount, 10);
      expect(snapshot.pushDeliveredCount, 8);
      expect(snapshot.pushFailedCount, 2);
      expect(snapshot.generatedAt, generatedAt);
      expect(snapshot.source, 'scheduled');
      expect(snapshot.windowHours, 24);
      expect(snapshot.sampledNotifications, 50);
    });

    test('fromMap gère dates ISO, millisecondes et valeurs invalides', () {
      final iso = AdminMessagingAnalyticsSnapshot.fromMap(
        <String, dynamic>{
          'generatedAt': '2026-07-15T10:00:00.000Z',
          'totalConversations': 'invalide',
          'averageResponseHours': 'invalide',
        },
      );
      final millis = AdminMessagingAnalyticsSnapshot.fromMap(
        <String, dynamic>{
          'generatedAt': 1000,
          'source': null,
          'windowHours': 'x',
          'sampledNotifications': 'x',
        },
      );
      final invalidDate = AdminMessagingAnalyticsSnapshot.fromMap(
        <String, dynamic>{'generatedAt': true},
      );

      expect(
        iso.generatedAt,
        DateTime.parse('2026-07-15T10:00:00.000Z'),
      );
      expect(iso.totalConversations, 0);
      expect(iso.averageResponseHours, 0);
      expect(millis.generatedAt?.millisecondsSinceEpoch, 1000);
      expect(millis.source, 'scheduled');
      expect(millis.windowHours, isNull);
      expect(millis.sampledNotifications, isNull);
      expect(invalidDate.generatedAt, isNull);
    });

    test('toMap restitue toutes les métriques', () {
      final generatedAt = DateTime.utc(2026, 7, 15, 12);
      final snapshot = AdminMessagingAnalyticsSnapshot(
        totalConversations: 1,
        activeToday: 2,
        totalMessages: 3,
        unansweredConversations: 4,
        reportedConversations: 5,
        blockedUsers: 6,
        attachmentsCount: 7,
        storageBytes: 8,
        activeUsers: 9,
        watchlistedConversations: 10,
        criticalRiskConversations: 11,
        pendingReports: 12,
        resolvedReports: 13,
        averageResponseHours: 14.5,
        providerResponseRate: 15.5,
        pushSentCount: 16,
        pushDeliveredCount: 17,
        pushFailedCount: 18,
        generatedAt: generatedAt,
        source: 'derived',
        windowHours: 24,
        sampledNotifications: 30,
      );

      expect(snapshot.toMap(), <String, dynamic>{
        'totalConversations': 1,
        'activeToday': 2,
        'totalMessages': 3,
        'unansweredConversations': 4,
        'reportedConversations': 5,
        'blockedUsers': 6,
        'attachmentsCount': 7,
        'storageBytes': 8,
        'activeUsers': 9,
        'watchlistedConversations': 10,
        'criticalRiskConversations': 11,
        'pendingReports': 12,
        'resolvedReports': 13,
        'averageResponseHours': 14.5,
        'providerResponseRate': 15.5,
        'pushSentCount': 16,
        'pushDeliveredCount': 17,
        'pushFailedCount': 18,
        'generatedAt': generatedAt.toIso8601String(),
        'source': 'derived',
        'windowHours': 24,
        'sampledNotifications': 30,
      });
    });
  });

  group('AdminMessagingAnalyticsService.buildSnapshot', () {
    AdminConversationModel conversation({
      required String id,
      DateTime? lastMessageAt,
      DateTime? updatedAt,
      int messageCount = 0,
      bool hasUnread = false,
      bool watchlisted = false,
      int riskScore = 0,
    }) {
      return AdminConversationModel(
        id: id,
        shortId: id,
        contextId: '',
        contextTitle: 'Conversation',
        category: 'service',
        region: 'GP',
        participantIds: const <String>[],
        participantNames: const <String, String>{},
        createdAt: null,
        updatedAt: updatedAt,
        lastMessageAt: lastMessageAt,
        messageCount: messageCount,
        status: 'active',
        riskScore: riskScore,
        reportCount: 0,
        adminWatchlisted: watchlisted,
        hasAttachments: false,
        hasUnread: hasUnread,
      );
    }

    AdminMessagingUserModel user({
      required String uid,
      String role = 'user',
      String status = 'actif',
      int messagesSent = 0,
      int openConversations = 0,
      double responseRate = 0,
      double averageResponseHours = 0,
    }) {
      return AdminMessagingUserModel(
        uid: uid,
        name: uid,
        email: '',
        role: role,
        region: 'GP',
        createdAt: null,
        lastActivityAt: null,
        openConversations: openConversations,
        messagesSent: messagesSent,
        messagesReceived: 0,
        reportsReceived: 0,
        reportsSent: 0,
        messagingStatus: status,
        riskScore: 0,
        responseRate: responseRate,
        averageResponseHours: averageResponseHours,
      );
    }

    AdminMessageReportModel report(String id, String status) {
      return AdminMessageReportModel(
        id: id,
        conversationId: 'conversation-$id',
        messageId: '',
        reportedBy: '',
        reportedUserId: '',
        reason: 'raison',
        description: '',
        priority: 'moyenne',
        status: status,
        assignedTo: '',
        adminDecision: '',
        createdAt: null,
        resolvedAt: null,
      );
    }

    const attachments = <AdminAttachmentModel>[
      AdminAttachmentModel(
        id: 'a1',
        conversationId: 'c1',
        messageId: 'm1',
        senderId: 'u1',
        storagePath: 'one',
        fileType: 'image',
        fileSize: 100,
        mimeType: 'image/jpeg',
        moderationStatus: 'ok',
        reportCount: 0,
        createdAt: null,
        deletedAt: null,
      ),
      AdminAttachmentModel(
        id: 'a2',
        conversationId: 'c2',
        messageId: 'm2',
        senderId: 'u2',
        storagePath: 'two',
        fileType: 'audio',
        fileSize: 250,
        mimeType: 'audio/mpeg',
        moderationStatus: 'ok',
        reportCount: 0,
        createdAt: null,
        deletedAt: null,
      ),
    ];

    test('agrège conversations, utilisateurs, rapports, fichiers et push', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final snapshot = const AdminMessagingAnalyticsService().buildSnapshot(
        conversations: <AdminConversationModel>[
          conversation(
            id: 'c1',
            lastMessageAt: now,
            messageCount: 4,
            hasUnread: true,
            watchlisted: true,
            riskScore: 90,
          ),
          conversation(
            id: 'c2',
            updatedAt: yesterday,
            messageCount: 6,
            riskScore: 20,
          ),
        ],
        attachments: attachments,
        users: <AdminMessagingUserModel>[
          user(
            uid: 'provider',
            role: 'prestataire pro',
            status: 'bloqué',
            messagesSent: 5,
            responseRate: 80,
            averageResponseHours: 2,
          ),
          user(
            uid: 'seller',
            role: 'seller',
            status: 'suspendu',
            openConversations: 1,
            responseRate: 60,
            averageResponseHours: 4,
          ),
          user(
            uid: 'inactive',
            role: 'user',
            responseRate: 100,
          ),
        ],
        reports: <AdminMessageReportModel>[
          report('1', ''),
          report('2', 'nouveau'),
          report('3', 'new'),
          report('4', 'pending'),
          report('5', 'en revue'),
          report('6', 'résolu'),
        ],
        notifications: const <AdminNotificationLogModel>[
          AdminNotificationLogModel(
            id: 'n1',
            userId: 'u1',
            title: '',
            body: '',
            routeName: '/messages',
            conversationId: 'c1',
            type: 'push',
            deliveryStatus: 'sent',
            createdAt: null,
          ),
          AdminNotificationLogModel(
            id: 'n2',
            userId: 'u2',
            title: '',
            body: '',
            routeName: '/messages',
            conversationId: 'c2',
            type: 'push',
            deliveryStatus: 'delivered',
            createdAt: null,
          ),
          AdminNotificationLogModel(
            id: 'n3',
            userId: 'u3',
            title: '',
            body: '',
            routeName: '/messages',
            conversationId: 'c3',
            type: 'push',
            deliveryStatus: 'erreur',
            createdAt: null,
          ),
          AdminNotificationLogModel(
            id: 'n4',
            userId: 'u4',
            title: '',
            body: '',
            routeName: '/messages',
            conversationId: 'c4',
            type: 'push',
            deliveryStatus: 'envoyé',
            createdAt: null,
          ),
          AdminNotificationLogModel(
            id: 'n5',
            userId: 'u5',
            title: '',
            body: '',
            routeName: '/messages',
            conversationId: 'c5',
            type: 'push',
            deliveryStatus: 'recu',
            createdAt: null,
          ),
          AdminNotificationLogModel(
            id: 'n6',
            userId: 'u6',
            title: '',
            body: '',
            routeName: '/messages',
            conversationId: 'c6',
            type: 'push',
            deliveryStatus: 'failed',
            createdAt: null,
          ),
          AdminNotificationLogModel(
            id: 'n7',
            userId: 'u7',
            title: '',
            body: '',
            routeName: '/messages',
            conversationId: 'c7',
            type: 'push',
            deliveryStatus: 'error',
            createdAt: null,
          ),
        ],
      );

      expect(snapshot.totalConversations, 2);
      expect(snapshot.activeToday, 1);
      expect(snapshot.totalMessages, 10);
      expect(snapshot.unansweredConversations, 1);
      expect(snapshot.reportedConversations, 6);
      expect(snapshot.blockedUsers, 2);
      expect(snapshot.attachmentsCount, 2);
      expect(snapshot.storageBytes, 350);
      expect(snapshot.activeUsers, 2);
      expect(snapshot.watchlistedConversations, 1);
      expect(snapshot.criticalRiskConversations, 1);
      expect(snapshot.pendingReports, 5);
      expect(snapshot.resolvedReports, 1);
      expect(snapshot.averageResponseHours, 3);
      expect(snapshot.providerResponseRate, 70);
      expect(snapshot.pushSentCount, 2);
      expect(snapshot.pushDeliveredCount, 2);
      expect(snapshot.pushFailedCount, 3);
      expect(snapshot.generatedAt, isNotNull);
      expect(snapshot.source, 'derived');
    });

    test('utilise les utilisateurs actifs sans prestataire', () {
      final snapshot = const AdminMessagingAnalyticsService().buildSnapshot(
        conversations: const <AdminConversationModel>[],
        attachments: const <AdminAttachmentModel>[],
        users: <AdminMessagingUserModel>[
          user(uid: 'u1', messagesSent: 1, responseRate: 40),
          user(uid: 'u2', messagesSent: 2, responseRate: 80),
          user(uid: 'u3'),
        ],
        reports: const <AdminMessageReportModel>[],
      );

      expect(snapshot.providerResponseRate, 60);
      expect(snapshot.averageResponseHours, 0);
      expect(snapshot.activeUsers, 2);
      expect(snapshot.pendingReports, 0);
      expect(snapshot.resolvedReports, 0);
    });

    test('retourne des zéros lorsque les collections sont vides', () {
      final snapshot = const AdminMessagingAnalyticsService().buildSnapshot(
        conversations: const <AdminConversationModel>[],
        attachments: const <AdminAttachmentModel>[],
        users: const <AdminMessagingUserModel>[],
        reports: const <AdminMessageReportModel>[],
      );

      expect(snapshot.totalConversations, 0);
      expect(snapshot.providerResponseRate, 0);
      expect(snapshot.averageResponseHours, 0);
      expect(snapshot.storageBytes, 0);
      expect(snapshot.pushSentCount, 0);
    });
  });
}
