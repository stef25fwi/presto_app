// Section tableau de bord de l'espace d'administration.
//
// Fragment de la bibliothèque `admin_space_page.dart` : le découpage
// réduit la taille des fichiers sans modifier la visibilité des types.
part of '../admin_space_page.dart';

class _AdminChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _AdminChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey.shade200,
            child: const Icon(
              Icons.person_rounded,
              size: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return ExcludeSemantics(child: content);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: content,
    );
  }
}

class _AdminDashboardSection extends StatefulWidget {
  final Map<String, dynamic>? userStats;
  final bool userStatsLoading;
  final List<_AdminMetricDomain> domains;
  final void Function(_AdminKpiSnapshot)? onComputed;

  const _AdminDashboardSection({
    required this.userStats,
    required this.userStatsLoading,
    required this.domains,
    this.onComputed,
  });

  @override
  State<_AdminDashboardSection> createState() => _AdminDashboardSectionState();
}

class _AdminDashboardSectionState extends State<_AdminDashboardSection> {
  _AdminDashboardWindow _window = _AdminDashboardWindow.day30;

  late Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _activeUsersStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _listingsStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _subscriptionsStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _billingInvoicesStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _analyticsStream;

  @override
  void initState() {
    super.initState();
    _rebuildStreams();
  }

  void _rebuildStreams() {
    final start = _startOfDay(
      DateTime.now(),
    ).subtract(Duration(days: _window.dayCount - 1));
    final startTimestamp = Timestamp.fromDate(start);
    _usersStream = FirebaseFirestore.instance
        .collection('users')
        .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
        .get()
        .asStream();
    _activeUsersStream = FirebaseFirestore.instance
        .collection('users')
        .where('lastSeenAt', isGreaterThanOrEqualTo: startTimestamp)
        .get()
        .asStream();
    _listingsStream = FirebaseFirestore.instance
        .collection('listings')
        .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
        .get()
        .asStream();
    _subscriptionsStream = FirebaseFirestore.instance
        .collection('subscriptions')
        .where('updatedAt', isGreaterThanOrEqualTo: startTimestamp)
        .get()
        .asStream();
    _billingInvoicesStream = FirebaseFirestore.instance
        .collection('billing_invoices')
        .where('updatedAt', isGreaterThanOrEqualTo: startTimestamp)
        .get()
        .asStream();
    _analyticsStream = FirebaseFirestore.instance
        .collection('analyticsSnapshots')
        .where('dateKey', isGreaterThanOrEqualTo: _dateKey(start))
        .get()
        .asStream();
  }

  Future<void> _openDomainDetails(_AdminDomainLiveData data) async {
    final csv = _buildAdminDomainCsv(data: data, window: _window);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _BottomSheetScaffold(
          title: 'Détails — ${data.domain.title}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final stat in data.highlights)
                    _DashboardPill(
                      label: stat.label,
                      value: stat.value,
                      color: data.domain.color,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _AdminMiniChart(
                color: data.domain.color,
                label: data.trendLabel,
                points: data.series,
              ),
              const SizedBox(height: 12),
              Text(
                data.note,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Catalogue métriques',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              ...data.domain.metrics.map(
                (metric) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• $metric',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: csv));
                        if (!sheetContext.mounted) return;
                        showSuccessSnackBar(sheetContext, 'CSV copié');
                      },
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Exporter CSV'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Dashboard admin: métriques clés',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
              ),
            ),
            _StatusBadge(
              label: _window.shortLabel,
              color: const Color(0xFF1A73E8),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Première vague branchée sur Firestore, Functions et analyticsSnapshots, avec filtre période et tendances miniatures.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final window in _AdminDashboardWindow.values)
              _WindowChip(
                label: window.label,
                selected: window == _window,
                onTap: () => setState(() {
                  _window = window;
                  _rebuildStreams();
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _usersStream,
          builder: (context, usersSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _activeUsersStream,
              builder: (context, activeUsersSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _listingsStream,
                  builder: (context, listingsSnapshot) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _subscriptionsStream,
                      builder: (context, subscriptionsSnapshot) {
                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
                          stream: _billingInvoicesStream,
                          builder: (context, billingInvoicesSnapshot) {
                            return StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>>(
                              stream: _analyticsStream,
                              builder: (context, analyticsSnapshot) {
                                final hasError = usersSnapshot.hasError ||
                                    activeUsersSnapshot.hasError ||
                                    listingsSnapshot.hasError ||
                                    subscriptionsSnapshot.hasError ||
                                    billingInvoicesSnapshot.hasError ||
                                    analyticsSnapshot.hasError;
                                if (hasError) {
                                  return const _SimpleAdminEmpty(
                                    message:
                                        'Impossible de charger une partie des métriques admin. Vérifie les droits et les index Firestore.',
                                  );
                                }

                                final waiting = usersSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    activeUsersSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    listingsSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    subscriptionsSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    billingInvoicesSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    analyticsSnapshot.connectionState ==
                                        ConnectionState.waiting;

                                final userDocs =
                                    usersSnapshot.data?.docs ?? const [];
                                final activeUserDocs =
                                    activeUsersSnapshot.data?.docs ?? const [];
                                final listingDocs =
                                    listingsSnapshot.data?.docs ?? const [];
                                final subscriptionDocs =
                                    subscriptionsSnapshot.data?.docs ??
                                        const [];
                                final billingDocs =
                                    billingInvoicesSnapshot.data?.docs ??
                                        const [];
                                final analyticsDocs =
                                    analyticsSnapshot.data?.docs ?? const [];

                                if (waiting &&
                                    userDocs.isEmpty &&
                                    activeUserDocs.isEmpty &&
                                    listingDocs.isEmpty &&
                                    analyticsDocs.isEmpty &&
                                    widget.userStatsLoading) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final computed =
                                    _AdminDashboardComputed.fromSources(
                                  userDocs: userDocs,
                                  activeUserDocs: activeUserDocs,
                                  listingDocs: listingDocs,
                                  analyticsDocs: analyticsDocs,
                                  subscriptionDocs: subscriptionDocs,
                                  billingDocs: billingDocs,
                                  userStats: widget.userStats,
                                  window: _window,
                                  domains: widget.domains,
                                );

                                if (widget.onComputed != null) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (!mounted) return;
                                    widget.onComputed!(
                                      _AdminKpiSnapshot(
                                        publishedListings:
                                            computed.publishedListings,
                                        activeListings: computed.activeListings,
                                        expiredListings:
                                            computed.expiredListings,
                                        messagesStarted:
                                            computed.messagesStarted,
                                        reportedListings:
                                            computed.reportedListings,
                                        blockedListings:
                                            computed.blockedListings,
                                        manualReviewListings:
                                            computed.manualReviewListings,
                                        activeSubscriptions:
                                            computed.activeSubscriptions,
                                        premiumUpgrades:
                                            computed.premiumUpgrades,
                                      ),
                                    );
                                  });
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GridView.count(
                                      crossAxisCount: 2,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 1.35,
                                      children: [
                                        _MetricCard(
                                          label: 'Nouveaux inscrits',
                                          value: _formatCompactNumber(
                                            computed.newUsers,
                                          ),
                                          icon: Icons.person_add_alt_1_rounded,
                                          color: const Color(0xFF1A73E8),
                                        ),
                                        _MetricCard(
                                          label: 'Utilisateurs actifs',
                                          value: _formatCompactNumber(
                                            computed.activeUsers,
                                          ),
                                          icon: Icons.groups_rounded,
                                          color: const Color(0xFF0F9D58),
                                        ),
                                        _MetricCard(
                                          label: 'Annonces publiées',
                                          value: _formatCompactNumber(
                                            computed.publishedListings,
                                          ),
                                          icon: Icons.campaign_rounded,
                                          color: const Color(0xFFFF6600),
                                        ),
                                        _MetricCard(
                                          label: 'Vues annonces',
                                          value: _formatCompactNumber(
                                            computed.listingViews,
                                          ),
                                          icon: Icons.visibility_rounded,
                                          color: const Color(0xFF8E24AA),
                                        ),
                                        _MetricCard(
                                          label: 'Factures payées',
                                          value: _formatCompactNumber(
                                            computed.paidInvoices,
                                          ),
                                          icon: Icons.receipt_long_rounded,
                                          color: const Color(0xFF00897B),
                                        ),
                                        _MetricCard(
                                          label: 'Revenu estimé',
                                          value: computed.revenueAmount <= 0
                                              ? '0 EUR'
                                              : '${_formatCompactNumber(computed.revenueAmount)} EUR',
                                          icon: Icons
                                              .account_balance_wallet_rounded,
                                          color: const Color(0xFF00897B),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Column(
                                      children: [
                                        for (final domain
                                            in computed.domains) ...[
                                          _AdminMetricDomainCard(
                                            domain: domain.domain,
                                            highlights: domain.highlights,
                                            series: domain.series,
                                            trendLabel: domain.trendLabel,
                                            note: domain.note,
                                            onTap: () =>
                                                _openDomainDetails(domain),
                                          ),
                                          if (domain != computed.domains.last)
                                            const SizedBox(height: 12),
                                        ],
                                      ],
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
      ],
    );
  }
}
