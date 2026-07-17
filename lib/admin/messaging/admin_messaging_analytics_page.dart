import 'package:flutter/material.dart';

import 'models/admin_attachment_model.dart';
import 'models/admin_conversation_model.dart';
import 'models/admin_message_report_model.dart';
import 'models/admin_messaging_user_model.dart';
import 'models/admin_notification_log_model.dart';
import 'services/admin_messaging_analytics_service.dart';
import 'services/admin_messaging_metrics_service.dart';
import 'services/admin_messaging_service.dart';
import 'services/admin_notification_monitor_service.dart';
import 'widgets/admin_messaging_stat_card.dart';

class AdminMessagingAnalyticsPage extends StatelessWidget {
  final Stream<List<AdminConversationModel>>? conversationsStream;
  final Stream<List<AdminMessageReportModel>>? reportsStream;
  final Stream<List<AdminMessagingUserModel>>? usersStream;
  final Stream<List<AdminAttachmentModel>>? attachmentsStream;
  final Stream<List<AdminNotificationLogModel>>? notificationsStream;
  final Stream<AdminMessagingAnalyticsSnapshot?>? metricsStream;

  const AdminMessagingAnalyticsPage({
    super.key,
    this.conversationsStream,
    this.reportsStream,
    this.usersStream,
    this.attachmentsStream,
    this.notificationsStream,
    this.metricsStream,
  });

  @override
  Widget build(BuildContext context) {
    final messagingService = AdminMessagingService();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: StreamBuilder<List<AdminConversationModel>>(
        stream: conversationsStream ??
            messagingService.watchConversations(limit: 200),
        builder: (context, conversationsSnapshot) {
          return StreamBuilder<List<AdminMessageReportModel>>(
            stream: reportsStream ?? messagingService.watchReports(limit: 200),
            builder: (context, reportsSnapshot) {
              return StreamBuilder<List<AdminMessagingUserModel>>(
                stream: usersStream ?? messagingService.watchUsers(limit: 200),
                builder: (context, usersSnapshot) {
                  return StreamBuilder<List<AdminAttachmentModel>>(
                    stream: attachmentsStream ??
                        messagingService.watchAttachments(limit: 200),
                    builder: (context, attachmentsSnapshot) {
                      return StreamBuilder<List<AdminNotificationLogModel>>(
                        stream: notificationsStream ??
                            AdminNotificationMonitorService()
                                .watchMessagingNotifications(limit: 200),
                        builder: (context, notificationsSnapshot) {
                          final conversations = conversationsSnapshot.data ??
                              const <AdminConversationModel>[];
                          final reports = reportsSnapshot.data ??
                              const <AdminMessageReportModel>[];
                          final users = usersSnapshot.data ??
                              const <AdminMessagingUserModel>[];
                          final attachments = attachmentsSnapshot.data ??
                              const <AdminAttachmentModel>[];
                          final notifications = notificationsSnapshot.data ??
                              const <AdminNotificationLogModel>[];
                          if (conversationsSnapshot.connectionState ==
                                  ConnectionState.waiting &&
                              conversations.isEmpty) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final derivedAnalytics =
                              const AdminMessagingAnalyticsService()
                                  .buildSnapshot(
                            conversations: conversations,
                            attachments: attachments,
                            users: users,
                            reports: reports,
                            notifications: notifications,
                          );
                          return StreamBuilder<
                              AdminMessagingAnalyticsSnapshot?>(
                            stream: metricsStream ??
                                AdminMessagingMetricsService()
                                    .watchCurrentMetrics(),
                            builder: (context, metricsSnapshot) {
                              final analytics =
                                  metricsSnapshot.data ?? derivedAnalytics;
                              return ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Text(
                                      analytics.source == 'scheduled'
                                          ? 'Source backend dédiée • fenêtre ${analytics.windowHours ?? 1} h • notifications échantillonnées ${analytics.sampledNotifications ?? 0}'
                                          : 'Fallback local basé sur les métadonnées chargées dans l\'interface.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: analytics.source == 'scheduled'
                                            ? const Color(0xFF0F766E)
                                            : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      SizedBox(
                                        width: 280,
                                        child: AdminMessagingStatCard(
                                          title: 'Messages cumulés',
                                          value: '${analytics.totalMessages}',
                                          subtitle:
                                              'sur les conversations agrégées',
                                          icon: Icons.chat_bubble_rounded,
                                          color: const Color(0xFF1D4ED8),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 280,
                                        child: AdminMessagingStatCard(
                                          title: 'Délai moyen',
                                          value:
                                              '${analytics.averageResponseHours.toStringAsFixed(1)} h',
                                          subtitle:
                                              'réponse observée côté utilisateurs actifs',
                                          icon: Icons.timer_outlined,
                                          color: const Color(0xFFD97706),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 280,
                                        child: AdminMessagingStatCard(
                                          title:
                                              'Taux de réponse prestataires',
                                          value:
                                              '${analytics.providerResponseRate.toStringAsFixed(0)} %',
                                          subtitle:
                                              'moyenne des rôles prestataire/pro quand disponibles',
                                          icon: Icons.support_agent_rounded,
                                          color: const Color(0xFF0F766E),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 280,
                                        child: AdminMessagingStatCard(
                                          title: 'Push en échec',
                                          value: '${analytics.pushFailedCount}',
                                          subtitle:
                                              '${analytics.pushSentCount} envoyés • ${analytics.pushDeliveredCount} délivrés',
                                          icon: Icons
                                              .notification_important_rounded,
                                          color: const Color(0xFFB42318),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Notes de lecture',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'La page privilégie désormais un document d\'agrégats backend dédié. En absence de synchro Functions, elle retombe automatiquement sur un calcul local sûr côté confidentialité.',
                                          style: TextStyle(
                                            color: Color(0xFF6B7280),
                                            fontWeight: FontWeight.w600,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
