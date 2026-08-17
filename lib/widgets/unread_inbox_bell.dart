import 'package:flutter/material.dart';

import '../services/inbox_counts.dart';
import '../services/presto_monitoring.dart' show PrestoMonitoring;

/// Fournit le nombre de messages/notifications non lus à un `builder`
/// (typiquement une icône avec badge). Extrait de `pages/home_page.dart`
/// pour rester sous le budget de lignes d'un écran.
class UnreadInboxBell extends StatelessWidget {
  final String userId;
  final String? monitoringKeyPrefix;
  final InboxCountType countType;
  final Widget Function(BuildContext context, int badgeCount) builder;

  const UnreadInboxBell({
    super.key,
    required this.userId,
    required this.builder,
    this.monitoringKeyPrefix,
    this.countType = InboxCountType.totalUnread,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: streamInboxCount(userId: userId, type: countType),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error != null) {
            PrestoMonitoring.I.trackError(
              '${monitoringKeyPrefix ?? 'messages'}.badge',
              error,
            );
          }
          return builder(context, 0);
        }

        final badgeCount = snapshot.data ?? 0;

        if (monitoringKeyPrefix != null) {
          PrestoMonitoring.I.trackOtherStream(
            key: '${monitoringKeyPrefix!}.badge',
            docsCount: badgeCount,
          );
        }

        return builder(context, badgeCount);
      },
    );
  }
}
