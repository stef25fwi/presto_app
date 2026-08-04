// Fenêtres temporelles et statistiques élémentaires du tableau de bord.
//
// Fragment de la bibliothèque `admin_space_page.dart` : le découpage
// réduit la taille des fichiers sans modifier la visibilité des types.
part of '../admin_space_page.dart';

enum _EmailDashboardWindow { hour1, day1, day7 }

enum _AdminDashboardWindow { day7, day30, day90 }

extension _AdminDashboardWindowX on _AdminDashboardWindow {
  String get label {
    switch (this) {
      case _AdminDashboardWindow.day7:
        return '7 jours';
      case _AdminDashboardWindow.day30:
        return '30 jours';
      case _AdminDashboardWindow.day90:
        return '90 jours';
    }
  }

  String get shortLabel {
    switch (this) {
      case _AdminDashboardWindow.day7:
        return '7j';
      case _AdminDashboardWindow.day30:
        return '30j';
      case _AdminDashboardWindow.day90:
        return '90j';
    }
  }

  int get dayCount {
    switch (this) {
      case _AdminDashboardWindow.day7:
        return 7;
      case _AdminDashboardWindow.day30:
        return 30;
      case _AdminDashboardWindow.day90:
        return 90;
    }
  }
}

class _AdminDashboardStat {
  final String label;
  final String value;

  const _AdminDashboardStat({required this.label, required this.value});
}

class _AdminDomainLiveData {
  final _AdminMetricDomain domain;
  final List<_AdminDashboardStat> highlights;
  final List<double> series;
  final String trendLabel;
  final String note;

  const _AdminDomainLiveData({
    required this.domain,
    required this.highlights,
    required this.series,
    required this.trendLabel,
    required this.note,
  });
}

class _AdminKpiSnapshot {
  final int publishedListings;
  final int activeListings;
  final int expiredListings;
  final int messagesStarted;
  final int reportedListings;
  final int blockedListings;
  final int manualReviewListings;
  final int activeSubscriptions;
  final int premiumUpgrades;

  const _AdminKpiSnapshot({
    required this.publishedListings,
    required this.activeListings,
    required this.expiredListings,
    required this.messagesStarted,
    required this.reportedListings,
    required this.blockedListings,
    required this.manualReviewListings,
    required this.activeSubscriptions,
    required this.premiumUpgrades,
  });
}
