import 'package:flutter/material.dart';
import 'package:presto_app/pages/pricing_calculator_page.dart';
import 'package:presto_app/pages/toolbox_je_me_lance_page.dart';

/// ==========================
/// ROUTES (optionnel)
/// ==========================
class AppRoutes {
  static const toolboxHub = '/toolbox_hub';
  static const toolboxCurrent = '/toolbox_current';
  static const entrepreneurCalculator = '/entrepreneur_calculator';
}

/// ==========================
/// PAGE HUB : Boîte à outils (2 cards)
/// ==========================
class ToolboxHubPage extends StatelessWidget {
  const ToolboxHubPage({super.key});

  // Couleurs proches de la charte Prestō
  static const Color prestoOrange = Color(0xFFFF6600);
  static const Color prestoBlue = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isPhone = mq.size.width < 700;

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
        "Plan d’actions sur 30 jours",
      ],
      buttonText: 'Démarrer mon projet',
      buttonGradient: const LinearGradient(
        colors: [Color(0xFF42A5F5), Color(0xFF1250B0)],
      ),
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
            if (isPhone) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: firstCard,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: secondCard,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
              children: [
                firstCard,
                const SizedBox(height: 10),
                secondCard,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ==========================
/// WIDGET CARD (réutilisable)
/// ==========================
class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.bullets,
    required this.buttonText,
    required this.buttonGradient,
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
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 10 : 12,
          compact ? 10 : 12,
          compact ? 10 : 12,
          compact ? 10 : 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                        style: TextStyle(
                          fontSize: compact ? 15 : 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: compact ? 3 : 4),
                      Text(
                        subtitle,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: compact ? 4 : 5),
                      Text(
                        description,
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 11 : 12,
                          color: Colors.black.withOpacity(0.70),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 10),
            _BulletsGrid(bullets: bullets),
            if (compact) const Spacer() else const SizedBox(height: 12),
            SizedBox(height: compact ? 8 : 0),
            SizedBox(
              width: double.infinity,
              height: compact ? 41 : 44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: buttonGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: buttonGradient.colors.last.withOpacity(0.35),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: onPressed,
                  child: Text(
                    buttonText,
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w800,
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
    final left = <String>[];
    final right = <String>[];
    for (int i = 0; i < bullets.length; i++) {
      (i.isEven ? left : right).add(bullets[i]);
    }

    return Row(
      children: [
        Expanded(child: _BulletColumn(items: left)),
        const SizedBox(width: 12),
        Expanded(child: _BulletColumn(items: right)),
      ],
    );
  }
}

class _BulletColumn extends StatelessWidget {
  const _BulletColumn({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 15, color: Color(0xFF2EAD6B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
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

/// ==========================
/// PLACEHOLDERS : remplace par TES pages
/// ==========================

/// Page actuelle "boîte à outils" (réutilise la page réelle existante)
class CurrentToolboxPage extends StatelessWidget {
  const CurrentToolboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    // On réutilise la page existante pour conserver le comportement actuel.
    return const ToolboxJeMeLancePage();
  }
}

/// Future page calculatrice (placeholder)
class EntrepreneurCalculatorPage extends StatelessWidget {
  const EntrepreneurCalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrestoPriceCalculatorApp();
  }
}
