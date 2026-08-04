// Calcul des indicateurs consolidés du tableau de bord.
//
// Fragment de la bibliothèque `admin_space_page.dart` : le découpage
// réduit la taille des fichiers sans modifier la visibilité des types.
part of '../admin_space_page.dart';

class _AdminDashboardComputed {
  final int newUsers;
  final int activeUsers;
  final int publishedListings;
  final int activeListings;
  final int expiredListings;
  final int listingViews;
  final int messagesStarted;
  final int premiumUpgrades;
  final int paidInvoices;
  final int failedInvoices;
  final double revenueAmount;
  final int reportedListings;
  final int blockedListings;
  final int manualReviewListings;
  final int activeSubscriptions;
  final List<_AdminDomainLiveData> domains;

  const _AdminDashboardComputed({
    required this.newUsers,
    required this.activeUsers,
    required this.publishedListings,
    required this.activeListings,
    required this.expiredListings,
    required this.listingViews,
    required this.messagesStarted,
    required this.premiumUpgrades,
    required this.paidInvoices,
    required this.failedInvoices,
    required this.revenueAmount,
    required this.reportedListings,
    required this.blockedListings,
    required this.manualReviewListings,
    required this.activeSubscriptions,
    required this.domains,
  });

  factory _AdminDashboardComputed.fromSources({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> activeUserDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> listingDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> analyticsDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> subscriptionDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> billingDocs,
    required Map<String, dynamic>? userStats,
    required _AdminDashboardWindow window,
    required List<_AdminMetricDomain> domains,
  }) {
    final totalAccounts = _toInt(userStats?['totalAccounts']);
    final onlineUsers = _toInt(userStats?['onlineUsers']);
    final start = _startOfDay(
      DateTime.now(),
    ).subtract(Duration(days: window.dayCount - 1));
    final bucketCount = window.dayCount;

    final userSeries = List<double>.filled(bucketCount, 0);
    final listingSeries = List<double>.filled(bucketCount, 0);
    final viewSeries = List<double>.filled(bucketCount, 0);
    final premiumSeries = List<double>.filled(bucketCount, 0);
    final billingSeries = List<double>.filled(bucketCount, 0);
    final moderationSeries = List<double>.filled(bucketCount, 0);
    final instrumentationSeries = List<double>.filled(bucketCount, 0);

    var completedProfiles = 0;
    for (final doc in userDocs) {
      final data = doc.data();
      if (_isCompleteAdminUser(data)) {
        completedProfiles += 1;
      }
      final index = _bucketIndexFor(
        _asDateTime(data['createdAt']),
        start,
        bucketCount,
      );
      if (index != null) {
        userSeries[index] += 1;
      }
    }

    final activeUsers = activeUserDocs.length;
    final dormantUsers =
        totalAccounts > activeUsers ? totalAccounts - activeUsers : 0;

    var activeListings = 0;
    var expiredListings = 0;
    var removedListings = 0;
    var reportedListings = 0;
    var blockedListings = 0;
    var manualReviewListings = 0;
    var totalRisk = 0.0;
    var lifespanDaysSum = 0.0;
    var lifespanCount = 0;
    var totalViews = 0;
    var totalContacts = 0;
    final owners = <String>{};
    final categoryCounts = <String, int>{};

    for (final doc in listingDocs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      final moderation =
          (data['moderationStatus'] ?? '').toString().trim().toLowerCase();
      final expiresAt = _asDateTime(data['expiresAt']);
      final createdAt = _asDateTime(data['createdAt']);
      final publishedAt = _asDateTime(data['publishedAt']) ?? createdAt;
      final ownerId =
          (data['ownerId'] ?? data['userId'] ?? '').toString().trim();
      final categoryLabel =
          (data['category'] ?? data['categoryId'] ?? 'Sans catégorie')
              .toString()
              .trim();

      if (ownerId.isNotEmpty) {
        owners.add(ownerId);
      }
      if (categoryLabel.isNotEmpty) {
        categoryCounts.update(
          categoryLabel,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }

      if (status == 'active') {
        activeListings += 1;
      }
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        expiredListings += 1;
      }
      if (status == 'deleted' || status == 'archived' || status == 'sold') {
        removedListings += 1;
      }

      final reportCount = _toInt(data['reportCount']);
      final viewCount = _toInt(data['viewCount']);
      final contactCount = _toInt(data['contactCount']);
      final riskScore = _toDouble(data['riskScore']);
      totalViews += viewCount;
      totalContacts += contactCount;
      totalRisk += riskScore;

      if (reportCount > 0) {
        reportedListings += 1;
      }
      if (moderation == 'blocked' || moderation == 'auto_flagged') {
        blockedListings += 1;
      }
      if (moderation == 'manual_review') {
        manualReviewListings += 1;
      }
      if (publishedAt != null && expiresAt != null) {
        lifespanDaysSum += expiresAt.difference(publishedAt).inHours / 24;
        lifespanCount += 1;
      }

      final index = _bucketIndexFor(createdAt, start, bucketCount);
      if (index != null) {
        listingSeries[index] += 1;
      }
    }

    final avgLifespanDays =
        lifespanCount == 0 ? 0.0 : lifespanDaysSum / lifespanCount;
    final avgRisk = listingDocs.isEmpty ? 0.0 : totalRisk / listingDocs.length;
    final conversionRatio = totalViews == 0 ? 0.0 : totalContacts / totalViews;
    final topCategory = _topEntryLabel(categoryCounts, fallback: '—');
    final advertiserRatio =
        activeUsers == 0 ? 0.0 : owners.length / activeUsers;

    final analyticsTotals = <String, int>{};
    var analyticsCoverageDays = 0;
    DateTime? latestAnalyticsDay;
    for (final doc in analyticsDocs) {
      final data = doc.data();
      if ((data['metricGroup'] ?? '').toString() != 'marketplace') {
        continue;
      }

      analyticsCoverageDays += 1;
      final date = DateTime.tryParse((data['dateKey'] ?? '').toString());
      if (date != null &&
          (latestAnalyticsDay == null || date.isAfter(latestAnalyticsDay))) {
        latestAnalyticsDay = date;
      }
      final index = _bucketIndexFor(date, start, bucketCount);
      final metrics = _stringKeyMap(data['metrics']);
      var totalDayEvents = 0;

      metrics.forEach((key, value) {
        final current = _toInt(value);
        analyticsTotals.update(
          key,
          (existing) => existing + current,
          ifAbsent: () => current,
        );
        totalDayEvents += current;
      });

      if (index != null) {
        viewSeries[index] += _toInt(metrics['listing_view']);
        premiumSeries[index] += _toInt(metrics['premium_upgrade_completed']);
        moderationSeries[index] += _toInt(metrics['listing_reported']);
        instrumentationSeries[index] += totalDayEvents;
      }
    }

    final searches = analyticsTotals['search_performed'] ?? 0;
    final messagesStarted = analyticsTotals['listing_message_started'] ?? 0;
    final premiumUpgrades = analyticsTotals['premium_upgrade_completed'] ?? 0;
    final reportEvents = analyticsTotals['listing_reported'] ?? 0;
    final totalTrackedEvents = analyticsTotals.values.fold<int>(
      0,
      (runningTotal, value) => runningTotal + value,
    );

    int sumByKeyPattern(RegExp pattern) {
      var sum = 0;
      analyticsTotals.forEach((key, value) {
        if (pattern.hasMatch(key)) {
          sum += value;
        }
      });
      return sum;
    }

    final errorEvents = sumByKeyPattern(
      RegExp(r'error|failed', caseSensitive: false),
    );
    final crashEvents = sumByKeyPattern(RegExp(r'crash', caseSensitive: false));

    double? metricFromMap(Map<String, dynamic> metrics, List<String> keys) {
      for (final key in keys) {
        if (metrics.containsKey(key)) {
          final value = _toDouble(metrics[key]);
          if (value > 0) return value;
        }
      }
      return null;
    }

    var latencySum = 0.0;
    var latencyCount = 0;
    var loadSum = 0.0;
    var loadCount = 0;
    for (final doc in analyticsDocs) {
      final data = doc.data();
      if ((data['metricGroup'] ?? '').toString() != 'marketplace') continue;
      final metrics = _stringKeyMap(data['metrics']);
      final latency = metricFromMap(metrics, const [
        'api_latency_ms_avg',
        'api_latency_ms',
        'latency_ms',
        'api_avg_ms',
      ]);
      if (latency != null) {
        latencySum += latency;
        latencyCount += 1;
      }
      final load = metricFromMap(metrics, const [
        'app_load_ms_avg',
        'app_load_ms',
        'app_start_ms',
        'page_load_ms',
      ]);
      if (load != null) {
        loadSum += load;
        loadCount += 1;
      }
    }

    final avgApiLatencyMs = latencyCount == 0 ? 0.0 : latencySum / latencyCount;
    final avgLoadMs = loadCount == 0 ? 0.0 : loadSum / loadCount;
    final errorCrashRate = totalTrackedEvents == 0
        ? 0.0
        : (errorEvents + crashEvents) / totalTrackedEvents;
    final uptimeRatio = (1.0 - errorCrashRate).clamp(0.0, 1.0);

    var activeSubscriptions = 0;
    for (final doc in subscriptionDocs) {
      final status =
          (doc.data()['status'] ?? '').toString().trim().toLowerCase();
      if (status == 'active' || status == 'trialing' || status == 'paid') {
        activeSubscriptions += 1;
      }
    }

    var paidInvoices = 0;
    var failedInvoices = 0;
    var refundOrDisputeCount = 0;
    var totalRevenue = 0.0;
    for (final doc in billingDocs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      final amount = _toDouble(
        data['amount_paid'] ?? data['amount_due'] ?? data['amount'] ?? 0,
      );
      final issuedAt = _asDateTime(
        data['createdAt'] ?? data['issued_at'] ?? data['updatedAt'],
      );
      final index = _bucketIndexFor(issuedAt, start, bucketCount);
      if (status == 'paid' ||
          status == 'succeeded' ||
          status == 'payment_succeeded') {
        paidInvoices += 1;
        totalRevenue += amount;
        if (index != null) {
          billingSeries[index] += amount;
        }
      } else if (status == 'failed' || status == 'payment_failed') {
        failedInvoices += 1;
      } else if (status.contains('refund') ||
          status.contains('dispute') ||
          status.contains('chargeback')) {
        refundOrDisputeCount += 1;
      }
    }

    final arpu = activeUsers == 0 ? 0.0 : totalRevenue / activeUsers;
    final paidConversion =
        activeUsers == 0 ? 0.0 : activeSubscriptions / activeUsers;

    final topPlatform = _topSourceLabel(userStats?['loginsByPlatform']);
    final topMethod = _topSourceLabel(userStats?['loginsByMethod']);

    final domainByTitle = {for (final domain in domains) domain.title: domain};

    _AdminMetricDomain domain(String title) =>
        domainByTitle[title] ??
        _AdminMetricDomain(
          title: title,
          icon: Icons.dashboard,
          color: const Color(0xFF1A73E8),
          metrics: const [],
        );

    final liveDomains = [
      _AdminDomainLiveData(
        domain: domain('Acquisition & trafic'),
        highlights: [
          _AdminDashboardStat(
            label: 'Nouveaux',
            value: _formatCompactNumber(userDocs.length),
          ),
          _AdminDashboardStat(
            label: 'Actifs',
            value: _formatCompactNumber(activeUsers),
          ),
          _AdminDashboardStat(
            label: 'En ligne',
            value: _formatCompactNumber(onlineUsers),
          ),
          _AdminDashboardStat(label: 'Top accès', value: topPlatform),
        ],
        series: userSeries,
        trendLabel: 'Inscriptions / jour',
        note:
            'Méthode dominante: $topMethod • CPA et sources d’acquisition à connecter.',
      ),
      _AdminDomainLiveData(
        domain: domain('Annonces & contenu'),
        highlights: [
          _AdminDashboardStat(
            label: 'Publiées',
            value: _formatCompactNumber(listingDocs.length),
          ),
          _AdminDashboardStat(
            label: 'Actives',
            value: _formatCompactNumber(activeListings),
          ),
          _AdminDashboardStat(
            label: 'Expirées',
            value: _formatCompactNumber(expiredListings),
          ),
          _AdminDashboardStat(
            label: 'Vie moy.',
            value: avgLifespanDays <= 0
                ? '—'
                : '${avgLifespanDays.toStringAsFixed(1)} j',
          ),
        ],
        series: listingSeries,
        trendLabel: 'Annonces créées / jour',
        note:
            'Top catégorie: $topCategory • Supprimées/retirées: ${_formatCompactNumber(removedListings)} • Signalées: ${_formatCompactNumber(reportedListings)}.',
      ),
      _AdminDomainLiveData(
        domain: domain('Utilisateurs'),
        highlights: [
          _AdminDashboardStat(
            label: 'Total comptes',
            value: _formatCompactNumber(totalAccounts),
          ),
          _AdminDashboardStat(
            label: 'Dormants',
            value: _formatCompactNumber(dormantUsers),
          ),
          _AdminDashboardStat(
            label: 'Annonceurs',
            value: _formatCompactNumber(owners.length),
          ),
          _AdminDashboardStat(
            label: 'Profils complets',
            value:
                '${_formatCompactNumber(completedProfiles)}/${_formatCompactNumber(userDocs.length)}',
          ),
        ],
        series: userSeries,
        trendLabel: 'Nouveaux inscrits / jour',
        note:
            'Ratio annonceurs / actifs: ${_formatPercent(advertiserRatio)} • Rétention et churn à connecter.',
      ),
      _AdminDomainLiveData(
        domain: domain('Engagement'),
        highlights: [
          _AdminDashboardStat(
            label: 'Vues',
            value: _formatCompactNumber(totalViews),
          ),
          _AdminDashboardStat(
            label: 'Contacts',
            value: _formatCompactNumber(totalContacts),
          ),
          _AdminDashboardStat(
            label: 'Conv. vue→contact',
            value: _formatPercent(conversionRatio),
          ),
          _AdminDashboardStat(
            label: 'Recherches',
            value: _formatCompactNumber(searches),
          ),
        ],
        series: viewSeries,
        trendLabel: 'Vues annonces / jour',
        note:
            'Messages démarrés: ${_formatCompactNumber(messagesStarted)} • Temps passé et top queries détaillées à connecter.',
      ),
      _AdminDomainLiveData(
        domain: domain('Transactions & revenus'),
        highlights: [
          _AdminDashboardStat(
            label: 'Upgrades premium',
            value: _formatCompactNumber(premiumUpgrades),
          ),
          _AdminDashboardStat(
            label: 'Abonnements actifs',
            value: _formatCompactNumber(activeSubscriptions),
          ),
          _AdminDashboardStat(
            label: 'ARPU',
            value: arpu <= 0 ? '0 EUR' : '${arpu.toStringAsFixed(2)} EUR',
          ),
          _AdminDashboardStat(
            label: 'GMV',
            value: totalRevenue <= 0
                ? '0 EUR'
                : '${_formatCompactNumber(totalRevenue)} EUR',
          ),
        ],
        series: billingSeries,
        trendLabel: 'Revenus facturés / jour',
        note:
            'Factures payées: ${_formatCompactNumber(paidInvoices)} • Échecs: ${_formatCompactNumber(failedInvoices)} • Litiges/remboursements: ${_formatCompactNumber(refundOrDisputeCount)} • Conversion payante: ${_formatPercent(paidConversion)}.',
      ),
      _AdminDomainLiveData(
        domain: domain('Qualité & modération'),
        highlights: [
          _AdminDashboardStat(
            label: 'Signalements',
            value: _formatCompactNumber(
              reportEvents > reportedListings ? reportEvents : reportedListings,
            ),
          ),
          _AdminDashboardStat(
            label: 'Fraude détectée',
            value: _formatCompactNumber(blockedListings),
          ),
          _AdminDashboardStat(
            label: 'En revue',
            value: _formatCompactNumber(manualReviewListings),
          ),
          _AdminDashboardStat(
            label: 'Risque moyen',
            value: avgRisk <= 0 ? '0' : avgRisk.toStringAsFixed(1),
          ),
        ],
        series: moderationSeries,
        trendLabel: 'Signalements / jour',
        note:
            'Temps moyen de modération et faux profils restent à instrumenter côté backend.',
      ),
      _AdminDomainLiveData(
        domain: domain('Technique & performance'),
        highlights: [
          _AdminDashboardStat(
            label: 'Événements suivis',
            value: _formatCompactNumber(totalTrackedEvents),
          ),
          _AdminDashboardStat(
            label: 'Jours couverts',
            value: _formatCompactNumber(analyticsCoverageDays),
          ),
          _AdminDashboardStat(
            label: 'Dernière maj',
            value:
                latestAnalyticsDay == null ? '—' : _dateKey(latestAnalyticsDay),
          ),
          _AdminDashboardStat(
            label: 'Crash+erreurs',
            value: _formatPercent(errorCrashRate),
          ),
          _AdminDashboardStat(
            label: 'Uptime estimée',
            value: _formatPercent(uptimeRatio),
          ),
          _AdminDashboardStat(
            label: 'Latence API',
            value: avgApiLatencyMs <= 0
                ? 'n/d'
                : '${avgApiLatencyMs.toStringAsFixed(0)} ms',
          ),
          _AdminDashboardStat(
            label: 'Chargement moyen',
            value:
                avgLoadMs <= 0 ? 'n/d' : '${avgLoadMs.toStringAsFixed(0)} ms',
          ),
        ],
        series: instrumentationSeries,
        trendLabel: 'Événements instrumentés / jour',
        note:
            'Ces indicateurs techniques sont calculés automatiquement à partir des métriques présentes dans analyticsSnapshots.',
      ),
    ];

    return _AdminDashboardComputed(
      newUsers: userDocs.length,
      activeUsers: activeUsers,
      publishedListings: listingDocs.length,
      activeListings: activeListings,
      expiredListings: expiredListings,
      listingViews: totalViews,
      messagesStarted: messagesStarted,
      premiumUpgrades: premiumUpgrades,
      paidInvoices: paidInvoices,
      failedInvoices: failedInvoices,
      revenueAmount: totalRevenue,
      reportedListings: reportedListings,
      blockedListings: blockedListings,
      manualReviewListings: manualReviewListings,
      activeSubscriptions: activeSubscriptions,
      domains: liveDomains,
    );
  }
}
