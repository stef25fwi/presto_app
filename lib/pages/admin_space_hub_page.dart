import 'package:flutter/material.dart';

import '../constants.dart';
import 'admin_space_page.dart';

class AdminSpaceHubPage extends StatelessWidget {
  const AdminSpaceHubPage({super.key});

  static const _sections = <_AdminHubSection>[
    _AdminHubSection(
      title: 'Acquisition & trafic',
      subtitle: 'Audience, canaux d’acquisition et coût de croissance.',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF1A73E8),
      metrics: <String>[
        'Visiteurs uniques (DAU / MAU)',
        'Sources de trafic',
        'Taux d’installation mobile',
        'Coût par acquisition',
      ],
    ),
    _AdminHubSection(
      title: 'Annonces & contenu',
      subtitle: 'Publication, activité, durée de vie et catégories.',
      icon: Icons.campaign_rounded,
      color: Color(0xFFFF6600),
      metrics: <String>[
        'Annonces publiées par période',
        'Actives, expirées et supprimées',
        'Taux de publication',
        'Durée moyenne de vie',
        'Catégories les plus populaires',
        'Annonces signalées ou modérées',
      ],
    ),
    _AdminHubSection(
      title: 'Utilisateurs',
      subtitle: 'Croissance, activité, rétention et qualité des profils.',
      icon: Icons.groups_rounded,
      color: Color(0xFF0F9D58),
      metrics: <String>[
        'Nouveaux inscrits',
        'Rétention J1, J7 et J30',
        'Taux de churn',
        'Actifs et dormants',
        'Annonceurs et chercheurs',
        'Profils complets et incomplets',
      ],
    ),
    _AdminHubSection(
      title: 'Engagement',
      subtitle: 'Vues, clics, contacts, recherches et conversion.',
      icon: Icons.insights_rounded,
      color: Color(0xFF8E24AA),
      metrics: <String>[
        'Vues moyennes par annonce',
        'Taux de clics',
        'Contacts et messages envoyés',
        'Conversion vue vers contact',
        'Temps passé dans l’application',
        'Recherches les plus fréquentes',
      ],
    ),
    _AdminHubSection(
      title: 'Transactions & revenus',
      subtitle: 'Abonnements, facturation, conversion et litiges.',
      icon: Icons.payments_rounded,
      color: Color(0xFF00897B),
      metrics: <String>[
        'Valeur brute des transactions',
        'Revenus publicitaires et premium',
        'Revenu moyen par utilisateur',
        'Conversion vers les offres payantes',
        'Remboursements et litiges',
      ],
    ),
    _AdminHubSection(
      title: 'Qualité & modération',
      subtitle: 'Signalements, fraude, faux profils et délais de traitement.',
      icon: Icons.verified_user_rounded,
      color: Color(0xFFD81B60),
      metrics: <String>[
        'Annonces frauduleuses détectées',
        'Temps moyen de modération',
        'Signalements utilisateurs',
        'Taux de faux profils',
      ],
    ),
    _AdminHubSection(
      title: 'Technique & performance',
      subtitle: 'Chargement, erreurs, disponibilité et latence.',
      icon: Icons.speed_rounded,
      color: Color(0xFF3949AB),
      metrics: <String>[
        'Temps de chargement moyen',
        'Taux de crash et d’erreurs',
        'Disponibilité du service',
        'Latence des API',
      ],
    ),
  ];

  void _openFullAdmin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminSpacePage()),
    );
  }

  void _openSection(BuildContext context, _AdminHubSection section) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AdminSectionDetailPage(section: section),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: const Text('Espace admin', style: kPrestoAppBarTitleStyle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AdminConfigurationCard(onTap: () => _openFullAdmin(context)),
              const SizedBox(height: 20),
              Text(
                'Pilotage de la plateforme',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF111827),
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Ouvre une tuile pour consulter les indicateurs et accéder au tableau détaillé.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1050
                      ? 3
                      : constraints.maxWidth >= 560
                          ? 2
                          : 1;
                  // La hauteur de tuile suit le facteur de texte : figée à
                  // 174 px, elle débordait dès 150 % d'agrandissement, à
                  // toutes les largeurs.
                  final tileExtent = MediaQuery.textScalerOf(
                    context,
                  ).scale(174);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _sections.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: tileExtent,
                    ),
                    itemBuilder: (context, index) {
                      final section = _sections[index];
                      return _AdminSectionTile(
                        section: section,
                        onTap: () => _openSection(context, section),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminConfigurationCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AdminConfigurationCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFFF6600);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFFFF0E6),
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.admin_panel_settings_rounded, color: color),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuration & conformité',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Mode d’exploitation, identité juridique, bêta gratuite, modération et outils techniques.',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminSectionTile extends StatelessWidget {
  final _AdminHubSection section;
  final VoidCallback onTap;

  const _AdminSectionTile({required this.section, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ouvrir ${section.title}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 16,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: section.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(section.icon, color: section.color, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        section.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 15,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: section.color),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  section.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: section.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${section.metrics.length} indicateurs',
                    style: TextStyle(
                      color: section.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSectionDetailPage extends StatelessWidget {
  final _AdminHubSection section;

  const _AdminSectionDetailPage({required this.section});

  void _openFullAdmin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminSpacePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(section.title, style: kPrestoAppBarTitleStyle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: section.color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(section.icon, color: section.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            section.subtitle,
                            style: const TextStyle(
                              color: Color(0xFF374151),
                              fontSize: 14,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Indicateurs suivis',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final metric in section.metrics)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: section.color,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                metric,
                                style: const TextStyle(
                                  color: Color(0xFF374151),
                                  fontSize: 13,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _openFullAdmin(context),
                style: FilledButton.styleFrom(
                  backgroundColor: section.color,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.dashboard_customize_rounded),
                label: const Text(
                  'Ouvrir le dashboard détaillé',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminHubSection {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> metrics;

  const _AdminHubSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.metrics,
  });
}
