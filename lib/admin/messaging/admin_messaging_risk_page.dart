import 'package:flutter/material.dart';

import 'models/admin_conversation_model.dart';
import 'models/admin_messaging_user_model.dart';
import 'services/admin_messaging_service.dart';
import 'widgets/admin_conversation_status_badge.dart';
import 'widgets/admin_risk_score_badge.dart';
import 'widgets/admin_user_messaging_status_badge.dart';

class AdminMessagingRiskPage extends StatelessWidget {
  final Stream<List<AdminConversationModel>>? conversationsStream;
  final Stream<List<AdminMessagingUserModel>>? usersStream;

  const AdminMessagingRiskPage({
    super.key,
    this.conversationsStream,
    this.usersStream,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: StreamBuilder<List<AdminConversationModel>>(
        stream: conversationsStream ??
            AdminMessagingService().watchConversations(limit: 200),
        builder: (context, conversationsSnapshot) {
          return StreamBuilder<List<AdminMessagingUserModel>>(
            stream:
                usersStream ?? AdminMessagingService().watchUsers(limit: 200),
            builder: (context, usersSnapshot) {
              final highRiskConversations = (conversationsSnapshot.data ??
                      const <AdminConversationModel>[])
                  .where(
                    (item) => item.riskScore >= 70 || item.adminWatchlisted,
                  )
                  .toList(growable: false);
              final highRiskUsers = (usersSnapshot.data ??
                      const <AdminMessagingUserModel>[])
                  .where(
                    (item) =>
                        item.riskScore >= 70 ||
                        item.messagingStatus.toLowerCase().contains('blo') ||
                        item.messagingStatus.toLowerCase().contains('suspend'),
                  )
                  .toList(growable: false);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _RiskHeaderCard(),
                  const SizedBox(height: 16),
                  _RiskSectionCard(
                    title: 'Conversations sensibles',
                    child: highRiskConversations.isEmpty
                        ? const _RiskEmptyState(
                            message:
                                'Aucune conversation à risque élevé dans le flux récent.',
                          )
                        : Column(
                            children: highRiskConversations.map((conversation) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.forum_rounded,
                                  color: Color(0xFFB42318),
                                ),
                                title: Text(conversation.contextTitle),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      AdminRiskScoreBadge(
                                        score: conversation.riskScore,
                                      ),
                                      AdminConversationStatusBadge(
                                        status: conversation.status,
                                      ),
                                      if (conversation.adminWatchlisted)
                                        const _RiskTag(label: 'Watchlist'),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(growable: false),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _RiskSectionCard(
                    title: 'Utilisateurs sensibles',
                    child: highRiskUsers.isEmpty
                        ? const _RiskEmptyState(
                            message:
                                'Aucun utilisateur sensible dans le flux récent.',
                          )
                        : Column(
                            children: highRiskUsers.map((user) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.person_off_rounded,
                                  color: Color(0xFFB42318),
                                ),
                                title: Text(user.name),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      AdminRiskScoreBadge(
                                        score: user.riskScore,
                                      ),
                                      AdminUserMessagingStatusBadge(
                                        status: user.messagingStatus,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(growable: false),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _RiskHeaderCard extends StatelessWidget {
  const _RiskHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Supervision des risques',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Cette vue regroupe les conversations watchlistées, les scores élevés et les comptes restreints à traiter en priorité.',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _RiskSectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RiskEmptyState extends StatelessWidget {
  final String message;

  const _RiskEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _RiskTag extends StatelessWidget {
  final String label;

  const _RiskTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFD97706).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFD97706),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
