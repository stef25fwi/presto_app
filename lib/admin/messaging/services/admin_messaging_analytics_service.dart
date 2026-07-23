import '../models/admin_attachment_model.dart';
import '../models/admin_conversation_model.dart';
import '../models/admin_message_report_model.dart';
import '../models/admin_notification_log_model.dart';
import '../models/admin_messaging_user_model.dart';

class AdminMessagingAnalyticsSnapshot {
  final int totalConversations;
  final int activeToday;
  final int totalMessages;
  final int unansweredConversations;
  final int reportedConversations;
  final int blockedUsers;
  final int attachmentsCount;
  final int storageBytes;
  final int activeUsers;
  final int watchlistedConversations;
  final int criticalRiskConversations;
  final int pendingReports;
  final int resolvedReports;
  final double averageResponseHours;
  final double providerResponseRate;
  final int pushSentCount;
  final int pushDeliveredCount;
  final int pushFailedCount;
  final DateTime? generatedAt;
  final String source;
  final int? windowHours;
  final int? sampledNotifications;

  const AdminMessagingAnalyticsSnapshot({
    required this.totalConversations,
    required this.activeToday,
    required this.totalMessages,
    required this.unansweredConversations,
    required this.reportedConversations,
    required this.blockedUsers,
    required this.attachmentsCount,
    required this.storageBytes,
    required this.activeUsers,
    required this.watchlistedConversations,
    required this.criticalRiskConversations,
    required this.pendingReports,
    required this.resolvedReports,
    required this.averageResponseHours,
    required this.providerResponseRate,
    required this.pushSentCount,
    required this.pushDeliveredCount,
    required this.pushFailedCount,
    this.generatedAt,
    this.source = 'derived',
    this.windowHours,
    this.sampledNotifications,
  });

  factory AdminMessagingAnalyticsSnapshot.fromMap(Map<String, dynamic> data) {
    int readInt(String key, [int fallback = 0]) {
      final value = data[key];
      if (value is num) return value.toInt();
      return int.tryParse('${value ?? fallback}') ?? fallback;
    }

    double readDouble(String key, [double fallback = 0]) {
      final value = data[key];
      if (value is num) return value.toDouble();
      return double.tryParse('${value ?? fallback}') ?? fallback;
    }

    DateTime? readDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    String readSource() {
      final value = data['source'];
      return value == null ? 'scheduled' : value.toString();
    }

    return AdminMessagingAnalyticsSnapshot(
      totalConversations: readInt('totalConversations'),
      activeToday: readInt('activeToday'),
      totalMessages: readInt('totalMessages'),
      unansweredConversations: readInt('unansweredConversations'),
      reportedConversations: readInt('reportedConversations'),
      blockedUsers: readInt('blockedUsers'),
      attachmentsCount: readInt('attachmentsCount'),
      storageBytes: readInt('storageBytes'),
      activeUsers: readInt('activeUsers'),
      watchlistedConversations: readInt('watchlistedConversations'),
      criticalRiskConversations: readInt('criticalRiskConversations'),
      pendingReports: readInt('pendingReports'),
      resolvedReports: readInt('resolvedReports'),
      averageResponseHours: readDouble('averageResponseHours'),
      providerResponseRate: readDouble('providerResponseRate'),
      pushSentCount: readInt('pushSentCount'),
      pushDeliveredCount: readInt('pushDeliveredCount'),
      pushFailedCount: readInt('pushFailedCount'),
      generatedAt: readDate(data['generatedAt']),
      source: readSource(),
      windowHours: data['windowHours'] is num
          ? (data['windowHours'] as num).toInt()
          : int.tryParse('${data['windowHours'] ?? ''}'),
      sampledNotifications: data['sampledNotifications'] is num
          ? (data['sampledNotifications'] as num).toInt()
          : int.tryParse('${data['sampledNotifications'] ?? ''}'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalConversations': totalConversations,
      'activeToday': activeToday,
      'totalMessages': totalMessages,
      'unansweredConversations': unansweredConversations,
      'reportedConversations': reportedConversations,
      'blockedUsers': blockedUsers,
      'attachmentsCount': attachmentsCount,
      'storageBytes': storageBytes,
      'activeUsers': activeUsers,
      'watchlistedConversations': watchlistedConversations,
      'criticalRiskConversations': criticalRiskConversations,
      'pendingReports': pendingReports,
      'resolvedReports': resolvedReports,
      'averageResponseHours': averageResponseHours,
      'providerResponseRate': providerResponseRate,
      'pushSentCount': pushSentCount,
      'pushDeliveredCount': pushDeliveredCount,
      'pushFailedCount': pushFailedCount,
      'generatedAt': generatedAt?.toIso8601String(),
      'source': source,
      'windowHours': windowHours,
      'sampledNotifications': sampledNotifications,
    };
  }
}

class AdminMessagingAnalyticsService {
  const AdminMessagingAnalyticsService();

  AdminMessagingAnalyticsSnapshot buildSnapshot({
    required List<AdminConversationModel> conversations,
    required List<AdminAttachmentModel> attachments,
    required List<AdminMessagingUserModel> users,
    required List<AdminMessageReportModel> reports,
    List<AdminNotificationLogModel> notifications =
        const <AdminNotificationLogModel>[],
  }) {
    final today = DateTime.now();
    final activeToday = conversations.where((conversation) {
      final last = conversation.lastMessageAt ?? conversation.updatedAt;
      return last != null &&
          last.year == today.year &&
          last.month == today.month &&
          last.day == today.day;
    }).length;
    final totalMessages = conversations.fold<int>(
      0,
      (sum, item) => sum + item.messageCount,
    );
    final unanswered = conversations.where((item) => item.hasUnread).length;
    final blockedUsers = users
        .where((item) =>
            item.messagingStatus == 'bloqué' ||
            item.messagingStatus == 'suspendu')
        .length;
    final activeUsers = users
        .where((item) => item.messagesSent > 0 || item.openConversations > 0)
        .length;
    final watchlistedConversations =
        conversations.where((item) => item.adminWatchlisted).length;
    final criticalRiskConversations =
        conversations.where((item) => item.riskScore >= 80).length;
    final pendingReports = reports.where((item) {
      final status = item.status.trim().toLowerCase();
      return status.isEmpty ||
          status == 'nouveau' ||
          status == 'new' ||
          status == 'pending' ||
          status == 'en revue';
    }).length;
    final resolvedReports = reports.length - pendingReports;
    final usersWithResponseDelay = users
        .where((item) => item.averageResponseHours > 0)
        .toList(growable: false);
    final averageResponseHours = usersWithResponseDelay.isEmpty
        ? 0
        : usersWithResponseDelay
                .map((item) => item.averageResponseHours)
                .reduce((left, right) => left + right) /
            usersWithResponseDelay.length;
    final providerUsers = users.where((item) {
      final role = item.role.trim().toLowerCase();
      return role.contains('provider') ||
          role.contains('prestataire') ||
          role.contains('seller') ||
          role.contains('vendeur') ||
          role.contains('pro');
    }).toList(growable: false);
    final usersForResponseRate = providerUsers.isNotEmpty
        ? providerUsers
        : users.where((item) => item.messagesSent > 0).toList(growable: false);
    final providerResponseRate = usersForResponseRate.isEmpty
        ? 0
        : usersForResponseRate
                .map((item) => item.responseRate)
                .reduce((left, right) => left + right) /
            usersForResponseRate.length;
    final storageBytes = attachments.fold<int>(
      0,
      (sum, item) => sum + item.fileSize,
    );
    final pushSentCount = notifications.where((item) {
      final status = item.deliveryStatus.trim().toLowerCase();
      return status.contains('sent') || status.contains('envoy');
    }).length;
    final pushDeliveredCount = notifications.where((item) {
      final status = item.deliveryStatus.trim().toLowerCase();
      return status.contains('deliver') || status.contains('recu');
    }).length;
    final pushFailedCount = notifications.where((item) {
      final status = item.deliveryStatus.trim().toLowerCase();
      return status.contains('fail') ||
          status.contains('error') ||
          status.contains('erreur');
    }).length;
    return AdminMessagingAnalyticsSnapshot(
      totalConversations: conversations.length,
      activeToday: activeToday,
      totalMessages: totalMessages,
      unansweredConversations: unanswered,
      reportedConversations: reports.length,
      blockedUsers: blockedUsers,
      attachmentsCount: attachments.length,
      storageBytes: storageBytes,
      activeUsers: activeUsers,
      watchlistedConversations: watchlistedConversations,
      criticalRiskConversations: criticalRiskConversations,
      pendingReports: pendingReports,
      resolvedReports: resolvedReports,
      averageResponseHours: averageResponseHours.toDouble(),
      providerResponseRate: providerResponseRate.toDouble(),
      pushSentCount: pushSentCount,
      pushDeliveredCount: pushDeliveredCount,
      pushFailedCount: pushFailedCount,
      generatedAt: DateTime.now(),
      source: 'derived',
    );
  }
}
