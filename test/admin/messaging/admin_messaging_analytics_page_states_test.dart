import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_messaging_analytics_page.dart';
import 'package:presto_app/admin/messaging/models/admin_attachment_model.dart';
import 'package:presto_app/admin/messaging/models/admin_conversation_model.dart';
import 'package:presto_app/admin/messaging/models/admin_message_report_model.dart';
import 'package:presto_app/admin/messaging/models/admin_messaging_user_model.dart';
import 'package:presto_app/admin/messaging/models/admin_notification_log_model.dart';
import 'package:presto_app/admin/messaging/services/admin_messaging_analytics_service.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required Stream<List<AdminConversationModel>> conversations,
    required Stream<List<AdminMessageReportModel>> reports,
    required Stream<List<AdminMessagingUserModel>> users,
    required Stream<List<AdminAttachmentModel>> attachments,
    required Stream<List<AdminNotificationLogModel>> notifications,
    required Stream<AdminMessagingAnalyticsSnapshot?> metrics,
  }) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminMessagingAnalyticsPage(
          conversationsStream: conversations,
          reportsStream: reports,
          usersStream: users,
          attachmentsStream: attachments,
          notificationsStream: notifications,
          metricsStream: metrics,
        ),
      ),
    );
  }

  Future<void> flushStreams(WidgetTester tester) async {
    for (var index = 0; index < 8; index++) {
      await tester.pump();
    }
  }

  testWidgets('affiche le chargement tant que les conversations attendent',
      (tester) async {
    final conversations = StreamController<List<AdminConversationModel>>();
    addTearDown(conversations.close);

    await pumpPage(
      tester,
      conversations: conversations.stream,
      reports: Stream.value(const <AdminMessageReportModel>[]),
      users: Stream.value(const <AdminMessagingUserModel>[]),
      attachments: Stream.value(const <AdminAttachmentModel>[]),
      notifications: Stream.value(const <AdminNotificationLogModel>[]),
      metrics: Stream.value(null),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Messages cumulés'), findsNothing);
  });

  testWidgets('affiche le fallback local avec des flux vides', (tester) async {
    await pumpPage(
      tester,
      conversations: Stream.value(const <AdminConversationModel>[]),
      reports: Stream.value(const <AdminMessageReportModel>[]),
      users: Stream.value(const <AdminMessagingUserModel>[]),
      attachments: Stream.value(const <AdminAttachmentModel>[]),
      notifications: Stream.value(const <AdminNotificationLogModel>[]),
      metrics: Stream.value(null),
    );
    await flushStreams(tester);

    expect(
      find.text(
        'Fallback local basé sur les métadonnées chargées dans l\'interface.',
      ),
      findsOneWidget,
    );
    expect(find.text('Messages cumulés'), findsOneWidget);
    expect(find.text('Délai moyen'), findsOneWidget);
    expect(find.text('Taux de réponse prestataires'), findsOneWidget);
    expect(find.text('Push en échec'), findsOneWidget);
    expect(find.text('0.0 h'), findsOneWidget);
    expect(find.text('0 %'), findsOneWidget);
    expect(find.text('0 envoyés • 0 délivrés'), findsOneWidget);
    expect(find.text('Notes de lecture'), findsOneWidget);
  });

  testWidgets('privilégie les métriques backend planifiées', (tester) async {
    const scheduled = AdminMessagingAnalyticsSnapshot(
      totalConversations: 12,
      activeToday: 8,
      totalMessages: 321,
      unansweredConversations: 3,
      reportedConversations: 2,
      blockedUsers: 1,
      attachmentsCount: 14,
      storageBytes: 2048,
      activeUsers: 10,
      watchlistedConversations: 2,
      criticalRiskConversations: 1,
      pendingReports: 2,
      resolvedReports: 5,
      averageResponseHours: 2.5,
      providerResponseRate: 76,
      pushSentCount: 20,
      pushDeliveredCount: 16,
      pushFailedCount: 4,
      source: 'scheduled',
      windowHours: 6,
      sampledNotifications: 40,
    );

    await pumpPage(
      tester,
      conversations: Stream.value(const <AdminConversationModel>[]),
      reports: Stream.value(const <AdminMessageReportModel>[]),
      users: Stream.value(const <AdminMessagingUserModel>[]),
      attachments: Stream.value(const <AdminAttachmentModel>[]),
      notifications: Stream.value(const <AdminNotificationLogModel>[]),
      metrics: Stream.value(scheduled),
    );
    await flushStreams(tester);

    expect(
      find.text(
        'Source backend dédiée • fenêtre 6 h • notifications échantillonnées 40',
      ),
      findsOneWidget,
    );
    expect(find.text('321'), findsOneWidget);
    expect(find.text('2.5 h'), findsOneWidget);
    expect(find.text('76 %'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('20 envoyés • 16 délivrés'), findsOneWidget);
  });
}
