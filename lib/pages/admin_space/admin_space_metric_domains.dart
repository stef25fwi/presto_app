// Domaines métier suivis par le tableau de bord d'administration.
//
// Fragment de la bibliothèque `admin_space_page.dart` : le découpage
// réduit la taille des fichiers sans modifier la visibilité des types.
part of '../admin_space_page.dart';

class _AdminMetricDomain {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> metrics;

  const _AdminMetricDomain({
    required this.title,
    required this.icon,
    required this.color,
    required this.metrics,
  });
}

const List<_AdminMetricDomain> _kAdminDashboardMetricDomains = [
  _AdminMetricDomain(
    title: 'Acquisition & trafic',
    icon: Icons.trending_up_rounded,
    color: Color(0xFF1A73E8),
    metrics: [
      'Visiteurs uniques (DAU / MAU)',
      'Sources de trafic (organique, direct, referral, paid)',
      'Taux d\'installation (si mobile)',
      'Coût par acquisition (CPA)',
    ],
  ),
  _AdminMetricDomain(
    title: 'Annonces & contenu',
    icon: Icons.campaign_rounded,
    color: Color(0xFFFF6600),
    metrics: [
      'Nombre d\'annonces publiées (total / par période)',
      'Annonces actives vs expirées vs supprimées',
      'Taux de publication (utilisateurs qui créent une annonce)',
      'Durée moyenne de vie d\'une annonce',
      'Catégories les plus populaires',
      'Annonces signalées / modérées',
    ],
  ),
  _AdminMetricDomain(
    title: 'Utilisateurs',
    icon: Icons.groups_rounded,
    color: Color(0xFF0F9D58),
    metrics: [
      'Nouveaux inscrits (par jour/semaine/mois)',
      'Taux de rétention (J1, J7, J30)',
      'Taux de churn',
      'Utilisateurs actifs vs dormants',
      'Ratio annonceurs / chercheurs',
      'Profils complétés vs incomplets',
    ],
  ),
  _AdminMetricDomain(
    title: 'Engagement',
    icon: Icons.insights_rounded,
    color: Color(0xFF8E24AA),
    metrics: [
      'Vues par annonce (moyenne)',
      'Taux de clics (CTR) sur les annonces',
      'Nombre de contacts / messages envoyés',
      'Taux de conversion (vue → contact)',
      'Temps passé sur l\'app',
      'Recherches effectuées (top queries)',
    ],
  ),
  _AdminMetricDomain(
    title: 'Transactions & revenus',
    icon: Icons.payments_rounded,
    color: Color(0xFF00897B),
    metrics: [
      'GMV (valeur brute des transactions)',
      'Revenus publicitaires / abonnements premium',
      'ARPU (revenu moyen par utilisateur)',
      'Taux de conversion vers offres payantes',
      'Remboursements / litiges',
    ],
  ),
  _AdminMetricDomain(
    title: 'Qualité & modération',
    icon: Icons.verified_user_rounded,
    color: Color(0xFFD81B60),
    metrics: [
      'Taux d\'annonces frauduleuses détectées',
      'Temps moyen de modération',
      'Nombre de signalements utilisateurs',
      'Taux de faux profils',
    ],
  ),
  _AdminMetricDomain(
    title: 'Technique & performance',
    icon: Icons.speed_rounded,
    color: Color(0xFF3949AB),
    metrics: [
      'Temps de chargement moyen',
      'Taux de crash / erreurs',
      'Disponibilité (uptime)',
      'Latence API',
    ],
  ),
];
