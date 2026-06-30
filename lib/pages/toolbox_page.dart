import 'package:flutter/material.dart';
import 'package:presto_app/pages/pricing_calculator_page.dart';
import 'package:presto_app/pages/toolbox_hub_page.dart';

import '../constants.dart';

/// Prestō / IliPrestō - Boîte à outils (présentation premium)
/// - Gradient orange en haut
/// - 2 cartes principales avec infos détaillées
/// - Style premium orange/bleu Prestō

class ToolboxPage extends StatelessWidget {
  const ToolboxPage({super.key});

  // Couleurs Prestō
  static const Color prestoOrange = Color(0xFFFF6A00);
  static const Color prestoBlue = Color(0xFF1A73E8);
  static const Color bg = Color(0xFFF6F7FB);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color success = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: prestoOrange,
        foregroundColor: Colors.white,
        title: const Text(
          'Boîte à outils',
          style: kPrestoAppBarTitleStyle,
        ),
      ),
      body: Stack(
        children: [
          // Header dégradé orange -> transparent (effet premium)
          const _TopGradient(),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(6, 16, 6, 24),
              children: [
                _BigToolCard(
                  icon: Icons.rocket_launch_rounded,
                  iconBg: const Color(0xFFFFE9DA),
                  title: 'Je me lance !',
                  subtitle: 'Crée ton entreprise simplement,\nsans te tromper.',
                  description:
                      'IliPrestō te guide de A à Z : projet, statut,\naides, coûts, démarches, plan d\'actions...',
                  items: const [
                    'Statut juridique\nconseillé',
                    'Coûts &\ndémarches\nexactes',
                    'Aides, subventions\n& organismes',
                    'Plan d\'actions\nsur 30 jours',
                  ],
                  ctaText: 'Démarrer mon projet',
                  ctaColor: prestoBlue,
                  footnote: 'Aucune démarche inutile - parcours personnalisé',
                  onCtaTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ToolboxHubPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),

                // Section title "Outils pour entrepreneurs"
                const _SectionTitle(
                  icon: Icons.work_outline,
                  title: 'Outils pour entrepreneurs',
                ),
                const SizedBox(height: 12),

                _BigToolCard(
                  icon: Icons.calculate_rounded,
                  iconBg: const Color(0xFFE8F0FF),
                  title: "La calculatrice de\nl'entrepreneur",
                  subtitle:
                      'Fixe le bon prix pour vendre\nsans perdre d\'argent',
                  description:
                      'En quelques clics, calcule ton coût de\nrevient, ton prix de vente conseillé et\ncompare avec le marché.',
                  items: const [
                    'Matières premières',
                    'Temps de travail',
                    'Charges & frais\nréels',
                    'Positionnement\nface à la\nconcurrence',
                  ],
                  ctaText: 'Calculer mon prix',
                  ctaColor: prestoOrange,
                  onCtaTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrestoPriceCalculatorApp(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),

                // (optionnel) carte suivante visible en bas comme sur le mockup
                _MiniPlaceholderCard(
                  title: 'Boite pour entrepreneurs',
                  icon: Icons.inventory_2_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopGradient extends StatelessWidget {
  const _TopGradient();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 190,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ToolboxPage.prestoOrange,
              Color(0x00FF6A00), // transparent
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              )
            ],
          ),
          child: Icon(Icons.work_outline,
              size: 18, color: ToolboxPage.textPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ToolboxPage.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _BigToolCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String description;
  final List<String> items;
  final String ctaText;
  final Color ctaColor;
  final String? footnote;
  final VoidCallback onCtaTap;

  const _BigToolCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.items,
    required this.ctaText,
    required this.ctaColor,
    this.footnote,
    required this.onCtaTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 16),
      decoration: BoxDecoration(
        color: ToolboxPage.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: ToolboxPage.prestoOrange, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: ToolboxPage.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ToolboxPage.textPrimary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14.5,
              color: ToolboxPage.textSecondary,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),

          // Liste en 2 colonnes (comme le mockup)
          _CheckGrid(items: items),

          const SizedBox(height: 14),

          // CTA large
          _PrimaryCTA(
            text: ctaText,
            color: ctaColor,
            onTap: onCtaTap,
          ),

          if (footnote != null) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                footnote!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ToolboxPage.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckGrid extends StatelessWidget {
  final List<String> items;

  const _CheckGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    // attendu: 4 items (2 colonnes x 2 lignes)
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _CheckItem(text: items.isNotEmpty ? items[0] : ''),
                const SizedBox(height: 14),
                _CheckItem(text: items.length > 2 ? items[2] : ''),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                _CheckItem(text: items.length > 1 ? items[1] : ''),
                const SizedBox(height: 14),
                _CheckItem(text: items.length > 3 ? items[3] : ''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;

  const _CheckItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: ToolboxPage.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              size: 16, color: ToolboxPage.success),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14.5,
              color: ToolboxPage.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryCTA extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _PrimaryCTA({
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: 58,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlaceholderCard extends StatelessWidget {
  final String title;
  final IconData icon;

  const _MiniPlaceholderCard({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: ToolboxPage.prestoBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: ToolboxPage.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
