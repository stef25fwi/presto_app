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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: prestoOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Boîte à outils'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _ToolCard(
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
            buttonColor: prestoBlue,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CurrentToolboxPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          _ToolCard(
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
            buttonColor: prestoOrange,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EntrepreneurCalculatorPage(),
                ),
              );
            },
          ),
        ],
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
    required this.buttonColor,
    required this.onPressed,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String description;
  final List<String> bullets;
  final String buttonText;
  final Color buttonColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.70),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _BulletsGrid(bullets: bullets),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: onPressed,
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: Color(0xFF2EAD6B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 14,
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
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: fg, size: 26),
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
