import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/services/admin_messaging_analytics_service.dart';

void main() {
  test('construit un snapshot vide cohérent', () {
    const service = AdminMessagingAnalyticsService();

    final snapshot = service.buildSnapshot(
      conversations: const [],
      attachments: const [],
      users: const [],
      reports: const [],
      notifications: const [],
    );

    expect(snapshot.totalConversations, 0);
    expect(snapshot.activeToday, 0);
    expect(snapshot.totalMessages, 0);
    expect(snapshot.unansweredConversations, 0);
    expect(snapshot.reportedConversations, 0);
    expect(snapshot.blockedUsers, 0);
    expect(snapshot.attachmentsCount, 0);
    expect(snapshot.storageBytes, 0);
    expect(snapshot.activeUsers, 0);
    expect(snapshot.watchlistedConversations, 0);
    expect(snapshot.criticalRiskConversations, 0);
    expect(snapshot.pendingReports, 0);
    expect(snapshot.resolvedReports, 0);
    expect(snapshot.averageResponseHours, 0);
    expect(snapshot.providerResponseRate, 0);
    expect(snapshot.pushSentCount, 0);
    expect(snapshot.pushDeliveredCount, 0);
    expect(snapshot.pushFailedCount, 0);
    expect(snapshot.generatedAt, isNotNull);
    expect(snapshot.source, 'derived');
  });

  test('utilise scheduled lorsque la source persistée est absente', () {
    final snapshot = AdminMessagingAnalyticsSnapshot.fromMap(
      const <String, dynamic>{},
    );

    expect(snapshot.source, 'scheduled');
    expect(snapshot.totalConversations, 0);
    expect(snapshot.windowHours, isNull);
    expect(snapshot.sampledNotifications, isNull);
  });
}
