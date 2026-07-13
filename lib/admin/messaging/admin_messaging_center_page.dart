import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/admin_access_state.dart';
import '../../pages/admin_messaging_moderation_page.dart';
import 'admin_messaging_access_policy.dart';
import 'admin_attachments_page.dart';
import 'admin_conversation_detail_page.dart';
import 'admin_message_report_detail_page.dart';
import 'admin_messaging_analytics_page.dart';
import 'admin_messaging_audit_logs_page.dart';
import 'admin_messaging_risk_page.dart';
import 'admin_messaging_settings_page.dart';
import 'admin_messaging_user_detail_page.dart';
import 'admin_notifications_monitor_page.dart';
import 'models/admin_attachment_model.dart';
import 'models/admin_conversation_model.dart';
import 'models/admin_message_report_model.dart';
import 'models/admin_messaging_user_model.dart';
import 'models/admin_notification_log_model.dart';
import 'services/admin_messaging_analytics_service.dart';
import 'services/admin_messaging_metrics_service.dart';
import 'services/admin_messaging_service.dart';
import 'services/admin_notification_monitor_service.dart';
import 'widgets/admin_conversation_status_badge.dart';
import 'widgets/admin_messaging_filter_bar.dart';
import 'widgets/admin_messaging_app_bar.dart';
import 'widgets/admin_messaging_stat_card.dart';
import 'widgets/admin_report_priority_badge.dart';
import 'widgets/admin_risk_score_badge.dart';
import 'widgets/admin_user_messaging_status_badge.dart';

enum AdminMessagingSection {
  dashboard,
  conversations,
  reports,
  risk,
  users,
  attachments,
  notifications,
  settings,
  audit,
  analytics,
}

extension AdminMessagingSectionX on AdminMessagingSection {
  String get label {
    switch (this) {
      case AdminMessagingSection.dashboard:
        return 'Vue d\'ensemble';
      case AdminMessagingSection.conversations:
        return 'Conversations';
      case AdminMessagingSection.reports:
        return 'Signalements';
      case AdminMessagingSection.risk:
        return 'Risque';
      case AdminMessagingSection.users:
        return 'Utilisateurs';
      case AdminMessagingSection.attachments:
        return 'Pièces jointes';
      case AdminMessagingSection.notifications:
        return 'Notifications';
      case AdminMessagingSection.settings:
        return 'Paramètres';
      case AdminMessagingSection.audit:
        return 'Audit';
      case AdminMessagingSection.analytics:
        return 'Analytics';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminMessagingSection.dashboard:
        return Icons.space_dashboard_rounded;
      case AdminMessagingSection.conversations:
        return Icons.forum_rounded;
      case AdminMessagingSection.reports:
        return Icons.flag_rounded;
      case AdminMessagingSection.risk:
        return Icons.gpp_maybe_rounded;
      case AdminMessagingSection.users:
        return Icons.groups_rounded;
      case AdminMessagingSection.attachments:
        return Icons.attach_file_rounded;
      case AdminMessagingSection.notifications:
        return Icons.notifications_active_rounded;
      case AdminMessagingSection.settings:
        return Icons.tune_rounded;
      case AdminMessagingSection.audit:
        return Icons.fact_check_rounded;
      case AdminMessagingSection.analytics:
        return Icons.insights_rounded;
    }
  }
}

class AdminMessagingCenterPage extends StatefulWidget {
  final AdminMessagingSection initialSection;
  final AdminAccessState? accessState;

  const AdminMessagingCenterPage({
    super.key,
    required this.initialSection,
    this.accessState,
  });

  @override
  State<AdminMessagingCenterPage> createState() =>
      _AdminMessagingCenterPageState();
}

class _AdminMessagingCenterPageState extends State<AdminMessagingCenterPage> {
  late AdminMessagingSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  static const AdminMessagingAccessPolicy _accessPolicy =
      AdminMessagingAccessPolicy();

  bool get _canManageSettings {
    final state = widget.accessState;
    if (state == null) return false;
    return _accessPolicy.canManageSettings(
      tokenRoles: state.tokenRoles,
      profileRoles: state.profileRoles,
      tokenPrimaryRole: state.tokenPrimaryRole,
      profilePrimaryRole: state.profilePrimaryRole,
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildSection();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AdminMessagingAppBar(
        title: 'Gestion messagerie - ${_section.label}',
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1080;
          if (isWide) {
            return Row(
              children: [
                _AdminMessagingRail(
                  selected: _section,
                  onSelect: (section) => setState(() => _section = section),
                ),
                Expanded(child: body),
              ],
            );
          }
          return Column(
            children: [
              _AdminMessagingTopSelector(
                selected: _section,
                onSelect: (section) => setState(() => _section = section),
              ),
              Expanded(child: body),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection() {
    switch (_section) {
      case AdminMessagingSection.dashboard:
        return _AdminMessagingDashboardSection(
          accessState: widget.accessState,
          onOpenSection: (section) => setState(() => _section = section),
        );
      case AdminMessagingSection.conversations:
        return const _AdminConversationsSection();
      case AdminMessagingSection.reports:
        return const _AdminReportsSection();
      case AdminMessagingSection.risk:
        return const AdminMessagingRiskPage();
      case AdminMessagingSection.users:
        return const _AdminMessagingUsersSection();
      case AdminMessagingSection.attachments:
        return const AdminAttachmentsPage();
      case AdminMessagingSection.notifications:
        return const AdminNotificationsMonitorPage(showAppBar: false);
      case AdminMessagingSection.settings:
        return AdminMessagingSettingsPage(canEdit: _canManageSettings);
      case AdminMessagingSection.audit:
        return const AdminMessagingAuditLogsPage();
      case AdminMessagingSection.analytics:
        return const AdminMessagingAnalyticsPage();
    }
  }
}

class _AdminMessagingRail extends StatelessWidget {
  final AdminMessagingSection selected;
  final ValueChanged<AdminMessagingSection> onSelect;

  const _AdminMessagingRail({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 244,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        child: NavigationRail(
          selectedIndex: AdminMessagingSection.values.indexOf(selected),
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: (index) {
            onSelect(AdminMessagingSection.values[index]);
          },
          destinations: AdminMessagingSection.values
              .map(
                (section) => NavigationRailDestination(
                  icon: Icon(section.icon),
                  label: Text(section.label),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _AdminMessagingTopSelector extends StatelessWidget {
  final AdminMessagingSection selected;
  final ValueChanged<AdminMessagingSection> onSelect;

  const _AdminMessagingTopSelector({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 8,
          children: AdminMessagingSection.values.map((section) {
            final selectedChip = section == selected;
            return ChoiceChip(
              selected: selectedChip,
              label: Text(section.label),
              avatar: Icon(section.icon, size: 18),
              onSelected: (_) => onSelect(section),
            );
          }).toList(growable: false),
        ),
      ),
    );
  }
}

class _AdminMessagingDataset {
  final List<AdminConversationModel> conversations;
  final List<AdminMessageReportModel> reports;
  final List<AdminMessagingUserModel> users;
  final List<AdminAttachmentModel> attachments;
  final List<AdminNotificationLogModel> notifications;

  const _AdminMessagingDataset({
    required this.conversations,
    required this.reports,
    required this.users,
    required this.attachments,
    required this.notifications,
  });
}

class _AdminMessagingDatasetBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, _AdminMessagingDataset dataset)
      builder;

  const _AdminMessagingDatasetBuilder({required this.builder});

  @override
  Widget build(BuildContext context) {
    final messagingService = AdminMessagingService();
    final notificationService = AdminNotificationMonitorService();

    return StreamBuilder<List<AdminConversationModel>>(
      stream: messagingService.watchConversations(limit: 120),
      builder: (context, conversationsSnapshot) {
        return StreamBuilder<List<AdminMessageReportModel>>(
          stream: messagingService.watchReports(limit: 120),
          builder: (context, reportsSnapshot) {
            return StreamBuilder<List<AdminMessagingUserModel>>(
              stream: messagingService.watchUsers(limit: 120),
              builder: (context, usersSnapshot) {
                return StreamBuilder<List<AdminAttachmentModel>>(
                  stream: messagingService.watchAttachments(limit: 120),
                  builder: (context, attachmentsSnapshot) {
                    return StreamBuilder<List<AdminNotificationLogModel>>(
                      stream: notificationService.watchMessagingNotifications(
                        limit: 120,
                      ),
                      builder: (context, notificationsSnapshot) {
                        final snapshots = [
                          conversationsSnapshot,
                          reportsSnapshot,
                          usersSnapshot,
                          attachmentsSnapshot,
                          notificationsSnapshot,
                        ];
                        final hasError = snapshots.any(
                          (snapshot) => snapshot.hasError,
                        );
                        final isWaiting = snapshots.any(
                          (snapshot) =>
                              snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData,
                        );

                        if (hasError) {
                          return _AdminMessagingErrorState(
                            message:
                                'Impossible de charger les données de supervision messagerie.',
                            onRetry: () async {
                              (context as Element).markNeedsBuild();
                            },
                          );
                        }

                        if (isWaiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        return builder(
                          context,
                          _AdminMessagingDataset(
                            conversations:
                                conversationsSnapshot.data ?? const [],
                            reports: reportsSnapshot.data ?? const [],
                            users: usersSnapshot.data ?? const [],
                            attachments: attachmentsSnapshot.data ?? const [],
                            notifications:
                                notificationsSnapshot.data ?? const [],
                          ),
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
  }
}

class _AdminMessagingDashboardSection extends StatelessWidget {
  final AdminAccessState? accessState;
  final ValueChanged<AdminMessagingSection> onOpenSection;

  const _AdminMessagingDashboardSection({
    required this.accessState,
    required this.onOpenSection,
  });

  @override
  Widget build(BuildContext context) {
    return _AdminMessagingDatasetBuilder(
      builder: (context, dataset) {
        final derivedAnalytics =
            const AdminMessagingAnalyticsService().buildSnapshot(
          conversations: dataset.conversations,
          attachments: dataset.attachments,
          users: dataset.users,
          reports: dataset.reports,
          notifications: dataset.notifications,
        );
        return StreamBuilder<AdminMessagingAnalyticsSnapshot?>(
          stream: AdminMessagingMetricsService().watchCurrentMetrics(),
          builder: (context, metricsSnapshot) {
            final analytics = metricsSnapshot.data ?? derivedAnalytics;
            final isSuperAdmin = _extractIsSuperAdmin(accessState);
            return _AdminMessagingSectionContainer(
              title: 'Pilotage messagerie',
              subtitle:
                  'Vue admin basée sur les métadonnées, la modération et les journaux. Aucun contenu de message n\'est relu ici.',
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!isSuperAdmin)
                    _AdminMessagingInfoBanner(
                      color: const Color(0xFF1D4ED8),
                      icon: Icons.lock_outline_rounded,
                      message:
                          'Les paramètres globaux restent en lecture seule hors superadmin. Les sections audit, signalements et modération restent accessibles.',
                    ),
                  const SizedBox(height: 12),
                  _AdminMessagingInfoBanner(
                    color: analytics.source == 'scheduled'
                        ? const Color(0xFF0F766E)
                        : const Color(0xFFD97706),
                    icon: analytics.source == 'scheduled'
                        ? Icons.cloud_done_rounded
                        : Icons.functions_rounded,
                    message: analytics.source == 'scheduled'
                        ? 'Métriques backend dédiées actives${analytics.generatedAt == null ? '' : ' • synchro ${analytics.generatedAt}'}.'
                        : 'Fallback local actif: les agrégats backend dédiés ne sont pas encore disponibles pour cette vue.',
                  ),
                  const SizedBox(height: 12),
                  _AdminDashboardStatGrid(
                    cards: [
                      AdminMessagingStatCard(
                        title: 'Conversations',
                        value: '${analytics.totalConversations}',
                        subtitle:
                            '${analytics.activeToday} actives aujourd\'hui\n${analytics.unansweredConversations} avec non-lu',
                        icon: Icons.forum_rounded,
                        color: const Color(0xFF1D4ED8),
                        onTap: () =>
                            onOpenSection(AdminMessagingSection.conversations),
                      ),
                      AdminMessagingStatCard(
                        title: 'Signalements',
                        value: '${analytics.reportedConversations}',
                        subtitle:
                            '${analytics.pendingReports} en attente\n${analytics.resolvedReports} traités',
                        icon: Icons.flag_rounded,
                        color: const Color(0xFFD97706),
                        onTap: () =>
                            onOpenSection(AdminMessagingSection.reports),
                      ),
                      AdminMessagingStatCard(
                        title: 'Risque élevé',
                        value: '${analytics.criticalRiskConversations}',
                        subtitle:
                            '${analytics.watchlistedConversations} watchlistées\n${analytics.blockedUsers} utilisateurs bloqués',
                        icon: Icons.gpp_maybe_rounded,
                        color: const Color(0xFFB42318),
                        onTap: () => onOpenSection(AdminMessagingSection.risk),
                      ),
                      AdminMessagingStatCard(
                        title: 'Push messagerie',
                        value: '${analytics.pushSentCount}',
                        subtitle:
                            '${analytics.pushDeliveredCount} délivrés\n${analytics.pushFailedCount} en échec',
                        icon: Icons.notifications_active_rounded,
                        color: const Color(0xFF0F766E),
                        onTap: () =>
                            onOpenSection(AdminMessagingSection.notifications),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _AdminDashboardSectionCard(
                    title: 'Priorités immédiates',
                    child: Column(
                      children: [
                        _PriorityRow(
                          title: 'Conversations à risque',
                          value: '${analytics.criticalRiskConversations}',
                          subtitle: 'score >= 80 ou watchlist admin',
                          color: const Color(0xFFB42318),
                        ),
                        const Divider(height: 20),
                        _PriorityRow(
                          title: 'Réponse prestataires',
                          value:
                              '${analytics.providerResponseRate.toStringAsFixed(0)} %',
                          subtitle:
                              'délai moyen ${analytics.averageResponseHours.toStringAsFixed(1)} h',
                          color: const Color(0xFF1D4ED8),
                        ),
                        const Divider(height: 20),
                        _PriorityRow(
                          title: 'Pièces jointes',
                          value: '${analytics.attachmentsCount}',
                          subtitle:
                              '${_formatBytes(analytics.storageBytes)} stockés',
                          color: const Color(0xFF7C3AED),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AdminDashboardSectionCard(
                    title: 'Accès rapides',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _QuickActionButton(
                          label: 'Ouvrir les conversations',
                          icon: Icons.forum_rounded,
                          onTap: () => onOpenSection(
                            AdminMessagingSection.conversations,
                          ),
                        ),
                        _QuickActionButton(
                          label: 'Traiter les signalements',
                          icon: Icons.flag_rounded,
                          onTap: () =>
                              onOpenSection(AdminMessagingSection.reports),
                        ),
                        _QuickActionButton(
                          label: 'Vérifier les utilisateurs',
                          icon: Icons.groups_rounded,
                          onTap: () =>
                              onOpenSection(AdminMessagingSection.users),
                        ),
                        _QuickActionButton(
                          label: 'Consulter l\'audit',
                          icon: Icons.fact_check_rounded,
                          onTap: () =>
                              onOpenSection(AdminMessagingSection.audit),
                        ),
                        _QuickActionButton(
                          label: 'Modération historique',
                          icon: Icons.shield_outlined,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const AdminMessagingModerationPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AdminDashboardSectionCard(
                    title: 'Derniers signalements',
                    child: Column(
                      children: dataset.reports.take(4).map((report) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.flag_rounded),
                          title: Text(report.reason),
                          subtitle: Text(
                            'Conversation ${report.conversationId.isEmpty ? 'inconnue' : report.conversationId} • ${report.status}',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AdminMessageReportDetailPage(
                                  report: report,
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(growable: false),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AdminConversationsSection extends StatefulWidget {
  const _AdminConversationsSection();

  @override
  State<_AdminConversationsSection> createState() =>
      _AdminConversationsSectionState();
}

class _AdminConversationsSectionState
    extends State<_AdminConversationsSection> {
  final AdminMessagingService _service = AdminMessagingService();
  final TextEditingController _controller = TextEditingController();
  final List<AdminConversationModel> _items = <AdminConversationModel>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  String _query = '';
  String? _statusFilter;
  bool _watchlistedOnly = false;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadingInitial = true;
      _loadingMore = false;
      _hasMore = true;
      _error = null;
      _lastDocument = null;
      _items.clear();
    });
    await _loadMore(reset: true);
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loadingMore) return;
    if (!reset && !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final page = await _service.fetchConversationsPage(
        pageSize: 40,
        startAfter: reset ? null : _lastDocument,
        status: _statusFilter,
        watchlisted: _watchlistedOnly ? true : null,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          _items.addAll(page.items);
        }
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loadingInitial = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((conversation) {
      return _matchesQuery(_query, [
        conversation.id,
        conversation.contextTitle,
        conversation.participantSummary,
        conversation.status,
        conversation.region,
      ]);
    }).toList(growable: false);

    return _AdminMessagingSectionContainer(
      title: 'Conversations récentes',
      subtitle: 'Vue de supervision, triée par activité la plus récente.',
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminMessagingFilterBar(
              controller: _controller,
              hintText: 'Recherche par annonce, participant, statut, région…',
              quickFilters: const ['active', 'reported', 'closed', 'watchlist'],
              onSubmitted: (value) => setState(() => _query = value),
              onQuickFilterTap: (value) {
                if (value == 'watchlist') {
                  setState(() {
                    _watchlistedOnly = true;
                    _query = '';
                    _controller.clear();
                  });
                  _refresh();
                  return;
                }
                _controller.text = value;
                setState(() {
                  _statusFilter = value;
                  _watchlistedOnly = false;
                  _query = value;
                });
                _refresh();
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Tous statuts'),
                  selected: _statusFilter == null && !_watchlistedOnly,
                  onSelected: (_) {
                    setState(() {
                      _statusFilter = null;
                      _watchlistedOnly = false;
                    });
                    _refresh();
                  },
                ),
                ...const ['active', 'reported', 'closed'].map(
                  (status) => FilterChip(
                    label: Text(status),
                    selected: _statusFilter == status,
                    onSelected: (_) {
                      setState(() {
                        _statusFilter = status;
                        _watchlistedOnly = false;
                      });
                      _refresh();
                    },
                  ),
                ),
                FilterChip(
                  label: const Text('Watchlist'),
                  selected: _watchlistedOnly,
                  onSelected: (_) {
                    setState(() {
                      _watchlistedOnly = !_watchlistedOnly;
                      if (_watchlistedOnly) {
                        _statusFilter = null;
                      }
                    });
                    _refresh();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loadingInitial && _items.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _AdminMessagingErrorState(
                message: 'Impossible de charger les conversations.',
                onRetry: _refresh,
              )
            else if (filtered.isEmpty)
              const _AdminMessagingEmptyState(
                title: 'Aucune conversation trouvée',
                subtitle: 'Ajustez la recherche ou élargissez les filtres.',
              )
            else
              ...filtered.map(
                (conversation) => _AdminListCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: const Color(
                        0xFF1D4ED8,
                      ).withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.forum_rounded,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    title: Text(
                      conversation.contextTitle,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(conversation.participantSummary),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              AdminConversationStatusBadge(
                                status: conversation.status,
                              ),
                              AdminRiskScoreBadge(
                                score: conversation.riskScore,
                              ),
                              if (conversation.adminWatchlisted)
                                _MiniTag(
                                  label: 'Watchlist',
                                  color: const Color(0xFFD97706),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${conversation.messageCount} messages • ${conversation.reportCount} signalements • ${conversation.region}',
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AdminConversationDetailPage(
                            conversation: conversation,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (_hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: _loadingMore ? null : _loadMore,
                    icon: _loadingMore
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded),
                    label: Text(
                      _loadingMore ? 'Chargement…' : 'Charger la page suivante',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminReportsSection extends StatefulWidget {
  const _AdminReportsSection();

  @override
  State<_AdminReportsSection> createState() => _AdminReportsSectionState();
}

class _AdminReportsSectionState extends State<_AdminReportsSection> {
  final AdminMessagingService _service = AdminMessagingService();
  final TextEditingController _controller = TextEditingController();
  final List<AdminMessageReportModel> _items = <AdminMessageReportModel>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  String _query = '';
  String? _statusFilter;
  String? _priorityFilter;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadingInitial = true;
      _loadingMore = false;
      _hasMore = true;
      _error = null;
      _lastDocument = null;
      _items.clear();
    });
    await _loadMore(reset: true);
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loadingMore) return;
    if (!reset && !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final page = await _service.fetchReportsPage(
        pageSize: 40,
        startAfter: reset ? null : _lastDocument,
        status: _statusFilter,
        priority: _priorityFilter,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          _items.addAll(page.items);
        }
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loadingInitial = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((report) {
      return _matchesQuery(_query, [
        report.conversationId,
        report.reason,
        report.status,
        report.priority,
        report.reportedUserId,
        report.reportedBy,
      ]);
    }).toList(growable: false);

    return _AdminMessagingSectionContainer(
      title: 'Signalements messagerie',
      subtitle: 'Traitement et décision admin sur les remontées utilisateur.',
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminMessagingFilterBar(
              controller: _controller,
              hintText: 'Recherche par motif, priorité, statut, utilisateur…',
              quickFilters: const ['nouveau', 'en revue', 'résolu', 'critique'],
              onSubmitted: (value) => setState(() => _query = value),
              onQuickFilterTap: (value) {
                _controller.text = value;
                setState(() {
                  _query = value;
                  if (value == 'critique') {
                    _priorityFilter = value;
                    _statusFilter = null;
                  } else {
                    _statusFilter = value;
                    _priorityFilter = null;
                  }
                });
                _refresh();
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Tous'),
                  selected: _statusFilter == null && _priorityFilter == null,
                  onSelected: (_) {
                    setState(() {
                      _statusFilter = null;
                      _priorityFilter = null;
                    });
                    _refresh();
                  },
                ),
                ...const ['nouveau', 'en revue', 'résolu'].map(
                  (status) => FilterChip(
                    label: Text(status),
                    selected: _statusFilter == status,
                    onSelected: (_) {
                      setState(() {
                        _statusFilter = status;
                        _priorityFilter = null;
                      });
                      _refresh();
                    },
                  ),
                ),
                ...const ['critique', 'haute'].map(
                  (priority) => FilterChip(
                    label: Text(priority),
                    selected: _priorityFilter == priority,
                    onSelected: (_) {
                      setState(() {
                        _priorityFilter = priority;
                        _statusFilter = null;
                      });
                      _refresh();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loadingInitial && _items.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _AdminMessagingErrorState(
                message: 'Impossible de charger les signalements.',
                onRetry: _refresh,
              )
            else if (filtered.isEmpty)
              const _AdminMessagingEmptyState(
                title: 'Aucun signalement trouvé',
                subtitle: 'Le flux est vide pour les critères sélectionnés.',
              )
            else
              ...filtered.map(
                (report) => _AdminListCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.flag_rounded,
                      color: Color(0xFFD97706),
                    ),
                    title: Text(
                      report.reason,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.description.trim().isEmpty
                                ? 'Aucune précision fournie.'
                                : report.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              AdminReportPriorityBadge(
                                priority: report.priority,
                              ),
                              _MiniTag(
                                label: report.status,
                                color: const Color(0xFF1D4ED8),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AdminMessageReportDetailPage(report: report),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (_hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: _loadingMore ? null : _loadMore,
                    icon: _loadingMore
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded),
                    label: Text(
                      _loadingMore ? 'Chargement…' : 'Charger la page suivante',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminMessagingUsersSection extends StatefulWidget {
  const _AdminMessagingUsersSection();

  @override
  State<_AdminMessagingUsersSection> createState() =>
      _AdminMessagingUsersSectionState();
}

class _AdminMessagingUsersSectionState
    extends State<_AdminMessagingUsersSection> {
  final AdminMessagingService _service = AdminMessagingService();
  final TextEditingController _controller = TextEditingController();
  final List<AdminMessagingUserModel> _items = <AdminMessagingUserModel>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  String _query = '';
  String? _statusFilter;
  String? _roleFilter;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadingInitial = true;
      _loadingMore = false;
      _hasMore = true;
      _error = null;
      _lastDocument = null;
      _items.clear();
    });
    await _loadMore(reset: true);
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loadingMore) return;
    if (!reset && !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final page = await _service.fetchUsersPage(
        pageSize: 40,
        startAfter: reset ? null : _lastDocument,
        messagingStatus: _statusFilter,
        role: _roleFilter,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          _items.addAll(page.items);
        }
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loadingInitial = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((user) {
      return _matchesQuery(_query, [
        user.uid,
        user.name,
        user.email,
        user.role,
        user.region,
        user.messagingStatus,
      ]);
    }).toList(growable: false);

    return _AdminMessagingSectionContainer(
      title: 'Utilisateurs messagerie',
      subtitle: 'Suivi des profils, de leur cadence de réponse et du risque.',
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminMessagingFilterBar(
              controller: _controller,
              hintText: 'Recherche par nom, email, rôle, région, statut…',
              quickFilters: const [
                'actif',
                'bloqué',
                'suspendu',
                'prestataire',
              ],
              onSubmitted: (value) => setState(() => _query = value),
              onQuickFilterTap: (value) {
                _controller.text = value;
                setState(() {
                  _query = value;
                  if (value == 'prestataire') {
                    _roleFilter = value;
                    _statusFilter = null;
                  } else {
                    _statusFilter = value;
                    _roleFilter = null;
                  }
                });
                _refresh();
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Tous'),
                  selected: _statusFilter == null && _roleFilter == null,
                  onSelected: (_) {
                    setState(() {
                      _statusFilter = null;
                      _roleFilter = null;
                    });
                    _refresh();
                  },
                ),
                ...const ['actif', 'bloqué', 'suspendu', 'restreint'].map(
                  (status) => FilterChip(
                    label: Text(status),
                    selected: _statusFilter == status,
                    onSelected: (_) {
                      setState(() {
                        _statusFilter = status;
                        _roleFilter = null;
                      });
                      _refresh();
                    },
                  ),
                ),
                ...const ['prestataire', 'pro', 'user'].map(
                  (role) => FilterChip(
                    label: Text(role),
                    selected: _roleFilter == role,
                    onSelected: (_) {
                      setState(() {
                        _roleFilter = role;
                        _statusFilter = null;
                      });
                      _refresh();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loadingInitial && _items.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _AdminMessagingErrorState(
                message: 'Impossible de charger les utilisateurs.',
                onRetry: _refresh,
              )
            else if (filtered.isEmpty)
              const _AdminMessagingEmptyState(
                title: 'Aucun utilisateur trouvé',
                subtitle: 'Aucun profil ne correspond aux filtres actuels.',
              )
            else
              ...filtered.map(
                (user) => _AdminListCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: const Color(
                        0xFF0F766E,
                      ).withValues(alpha: 0.12),
                      child: Text(
                        user.name.trim().isEmpty
                            ? '?'
                            : user.name.trim().substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.email.isEmpty ? user.uid : user.email),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              AdminUserMessagingStatusBadge(
                                status: user.messagingStatus,
                              ),
                              AdminRiskScoreBadge(score: user.riskScore),
                              _MiniTag(
                                label: user.role,
                                color: const Color(0xFF1D4ED8),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AdminMessagingUserDetailPage(user: user),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (_hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: _loadingMore ? null : _loadMore,
                    icon: _loadingMore
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded),
                    label: Text(
                      _loadingMore ? 'Chargement…' : 'Charger la page suivante',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminMessagingSectionContainer extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _AdminMessagingSectionContainer({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _AdminDashboardStatGrid extends StatelessWidget {
  final List<AdminMessagingStatCard> cards;

  const _AdminDashboardStatGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 700
                ? 2
                : 1;
        return GridView.builder(
          itemCount: cards.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 174,
          ),
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }
}

class _AdminDashboardSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _AdminDashboardSectionCard({required this.title, required this.child});

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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PriorityRow extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _PriorityRow({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _AdminListCard extends StatelessWidget {
  final Widget child;

  const _AdminListCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _AdminMessagingEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AdminMessagingEmptyState({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, size: 42, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _AdminMessagingErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _AdminMessagingErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 42,
            color: Color(0xFFB42318),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AdminMessagingInfoBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String message;

  const _AdminMessagingInfoBanner({
    required this.color,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _extractIsSuperAdmin(AdminAccessState? state) {
  if (state == null) return false;
  final roles = <String>{
    ...state.tokenRoles,
    ...state.profileRoles,
    state.tokenPrimaryRole ?? '',
    state.profilePrimaryRole ?? '',
  }.map((item) => item.trim().toLowerCase());
  return roles.contains('superadmin') || roles.contains('owner');
}

bool _matchesQuery(String query, List<String> candidates) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return true;
  return candidates.any(
    (candidate) => candidate.toLowerCase().contains(normalizedQuery),
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes o';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} Ko';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} Mo';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(1)} Go';
}
