import 'package:flutter/material.dart';
import 'package:presto_app/pages/pricing_calculator_page.dart';
import 'package:presto_app/pages/toolbox_je_me_lance_page.dart';

import '../constants.dart';

class AppRoutes {
  static const toolboxHub = '/toolbox_hub';
  static const toolboxCurrent = '/toolbox_current';
  static const entrepreneurCalculator = '/entrepreneur_calculator';
}

class ToolboxHubPage extends StatelessWidget {
  const ToolboxHubPage({super.key});

  static const Color prestoOrange = Color(0xFFFF6600);
  static const Color prestoBlue = Color(0xFF1A73E8);

  double _responsiveToolButtonHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;

    if (width < 360 || height < 640) return 52;
    if (width < 700) return 58;
    if (width < 1100) return 58;
    return 58;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isPhone = mq.size.width < 700;
    final toolButtonHeight = _responsiveToolButtonHeight(context);

    final firstCard = _ToolCard(
      leading: const _IconBadge(
        icon: Icons.rocket_launch_rounded,
        bg: Color(0xFFFFE6D6),
        fg: prestoOrange,
      ),
      title: 'Je me lance !',
      subtitle: 'IliPrestō te guide pour la création de ton entreprise.',
      description: 'Décris ton projet, ta situation et ton territoire.',
      bullets: const [
        'Statut juridique conseillé',
        'Coûts & démarches exactes',
        'Aides, subventions & organismes',
        'Plan d’actions sur 30 jours',
      ],
      buttonText: 'Démarrer mon projet',
      buttonGradient: const LinearGradient(
        colors: [Color(0xFF42A5F5), Color(0xFF1250B0)],
      ),
      buttonHeight: toolButtonHeight,
      compact: isPhone,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CurrentToolboxPage()),
        );
      },
    );

    final secondCard = _ToolCard(
      leading: const _IconBadge(
        icon: Icons.calculate_rounded,
        bg: Color(0xFFE7F0FF),
        fg: prestoBlue,
      ),
      title: "La calculatrice de l'entrepreneur",
      subtitle: 'Fixe le bon prix pour vendre sans perdre d’argent.',
      description:
          'En quelques clics, calcule ton coût de revient, ton prix de vente conseillé et compare avec le marché.',
      bullets: const [
        'Matières premières',
        'Temps de travail',
        'Charges & frais réels',
        'Positionnement face à la concurrence',
      ],
      buttonText: 'Calculer mon prix',
      buttonGradient: const LinearGradient(
        colors: [Color(0xFFFF8C00), Color(0xFFFF4500)],
      ),
      buttonHeight: toolButtonHeight,
      compact: isPhone,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EntrepreneurCalculatorPage(),
          ),
        );
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: prestoOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Boîte à outils'),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentPadding = isPhone
                ? const EdgeInsets.fromLTRB(6, 10, 6, 18)
                : const EdgeInsets.fromLTRB(6, 12, 6, 28);
            final cardSpacing = isPhone ? 12.0 : 22.0;

            // Les cartes conservent toujours leur hauteur intrinsèque. Une
            // hauteur forcée pouvait devenir insuffisante sur tablette ou avec
            // un facteur de texte élevé et faisait sortir le bouton de la carte.
            return ListView(
              padding: contentPadding,
              children: [
                firstCard,
                SizedBox(height: cardSpacing),
                secondCard,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.bullets,
    required this.buttonText,
    required this.buttonGradient,
    required this.buttonHeight,
    required this.compact,
    required this.onPressed,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String description;
  final List<String> bullets;
  final String buttonText;
  final LinearGradient buttonGradient;
  final double buttonHeight;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 14 : 16,
          compact ? 14 : 16,
          compact ? 14 : 16,
          compact ? 14 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: kPrestoCardTitleStyle.copyWith(
                          fontSize: compact ? 18 : 19,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      SizedBox(height: compact ? 3 : 4),
                      Text(
                        subtitle,
                        style: kPrestoMetaTextStyle.copyWith(
                          fontSize: compact ? 13.5 : 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: compact ? 4 : 5),
                      Text(
                        description,
                        style: kPrestoMetaTextStyle.copyWith(
                          fontSize: compact ? 13 : 13.5,
                          color: Colors.black.withValues(alpha: 0.70),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 14 : 16),
            _BulletsGrid(bullets: bullets),
            SizedBox(height: compact ? 16 : 18),
            SizedBox(
              width: double.infinity,
              height: buttonHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: buttonGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: buttonGradient.colors.last.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: Size.fromHeight(buttonHeight),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: onPressed,
                  child: Center(
                    child: Text(
                      buttonText,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize:
                            buttonHeight <= 52 ? 14.5 : (compact ? 15 : 16),
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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

class _BulletsGrid extends StatelessWidget {
  const _BulletsGrid({required this.bullets});

  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: 10,
          children: bullets
              .map(
                (bullet) => SizedBox(
                  width: itemWidth,
                  child: _BulletItem(text: bullet),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.check_circle_rounded,
            size: 17,
            color: Color(0xFF2EAD6B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.bg,
    required this.fg,
  });

  final IconData icon;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: fg, size: 22),
    );
  }
}

class CurrentToolboxPage extends StatelessWidget {
  const CurrentToolboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ToolboxJeMeLancePage();
  }
}

class CurrentToolboxSummaryPage extends StatelessWidget {
  const CurrentToolboxSummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ToolboxMyParcoursPage();
  }
}

class EntrepreneurCalculatorPage extends StatelessWidget {
  const EntrepreneurCalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrestoPriceCalculatorApp();
  }
}
