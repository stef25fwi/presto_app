import 'dart:ui';
import 'package:flutter/material.dart';

/// ------------------------------------------------------------
/// ACCUEIL "OPTION 2" (Marque forte équilibrée)
/// - Page prête à coller telle quelle
/// - Ouvrable via appui long sur le logo "iliprestō"
/// ------------------------------------------------------------

class HomePageV2Option2 extends StatelessWidget {
  const HomePageV2Option2({super.key});

  static const prestoOrange = Color(0xFFFF6600);
  static const prestoBlue = Color(0xFF1A73E8);
  static const bg = Color(0xFFF6F8FC);
  static const textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar (logo centered + bell)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
              child: Row(
                children: [
                  const SizedBox(width: 44), // to visually center logo
                  Expanded(
                    child: Center(
                      child: _LogoIlipresto(
                        onLongPress: () {
                          // Retour à la page principale
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ),
                  _CircleIconButton(
                    icon: Icons.notifications_none_rounded,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: _SearchBar(
                hint: "Que cherchez-vous ?",
                onChanged: (_) {},
                onSubmitted: (_) {},
              ),
            ),

            const SizedBox(height: 10),

            // Location row (Baie-Mahault • Autour de moi + chevron)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: _LocationBar(
                leftText: "Baie-Mahault",
                rightText: "Autour de moi",
                onTap: () {},
              ),
            ),

            const SizedBox(height: 10),

            // Filter chips
            Padding(
              padding: const EdgeInsets.only(left: 0),
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _ChipPill(
                      label: "Aujourd'hui",
                      selected: true,
                      onTap: () {},
                    ),
                    const SizedBox(width: 10),
                    _ChipPill(
                      label: "Autour de moi",
                      selected: false,
                      onTap: () {},
                    ),
                    const SizedBox(width: 10),
                    _ChipPill(
                      label: "Petit budget",
                      selected: false,
                      onTap: () {},
                    ),
                    const SizedBox(width: 10),
                    _ChipPill(
                      label: "Urgent",
                      selected: false,
                      onTap: () {},
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Content scroll
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero slider (single slide mock identical layout)
                    _HeroCardOption2(
                      title: "Publiez → Trouvez vite",
                      subtitle:
                          "Des prestataires proches voient\nvotre offre instantanément.",
                      cta: "Publier une offre",
                      onCta: () {},
                    ),

                    const SizedBox(height: 14),

                    // Categories header
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Catégories",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: const Text(
                            "Voir tout",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: prestoOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Category cards grid 2x2
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.55,
                      children: const [
                        _CategoryCard(
                          icon: Icons.eco_outlined,
                          title: "Jardinage",
                          subtitle: "Tonte, taille,\ndébroussaillage",
                        ),
                        _CategoryCard(
                          icon: Icons.format_paint_outlined,
                          title: "Peinture",
                          subtitle: "Murs, volets,\nretouches",
                        ),
                        _CategoryCard(
                          icon: Icons.handyman_outlined,
                          title: "Main-d'œuvre",
                          subtitle: "Aide, manutention,\ndéménagement",
                        ),
                        _CategoryCard(
                          icon: Icons.grid_view_rounded,
                          title: "Autres",
                          subtitle: "Tous les services",
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // How it works - Section dans une Card bien visible
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: prestoOrange.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: prestoOrange.withOpacity(0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  "Comment ça marche ?",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {},
                                child: const Text(
                                  "Voir plus",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: prestoOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Steps (compact)
                          const _StepCard(
                            number: 1,
                            title: "Je publie une offre",
                            subtitle: "Les prestataires proches sont notifiés",
                            showChevron: false,
                          ),
                          const SizedBox(height: 10),
                          const _StepCard(
                            number: 3,
                            title: "Je choisis et je valide",
                            subtitle: "",
                            showChevron: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation (Option 2)
      bottomNavigationBar: const _BottomNavOption2(currentIndex: 0),
    );
  }
}

/// ------------------------------------------------------------
/// Logo avec appui long
/// ------------------------------------------------------------
class _LogoIlipresto extends StatelessWidget {
  final VoidCallback? onLongPress;
  const _LogoIlipresto({this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: RichText(
        text: const TextSpan(
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
          children: [
            TextSpan(text: "ili", style: TextStyle(color: HomePageV2Option2.prestoOrange)),
            TextSpan(text: "presto", style: TextStyle(color: HomePageV2Option2.prestoOrange)),
            TextSpan(
              text: "ō",
              style: TextStyle(color: HomePageV2Option2.prestoOrange, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// UI Pieces
/// ------------------------------------------------------------

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black87),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const _SearchBar({
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          prefixIcon: const Icon(Icons.search, color: HomePageV2Option2.prestoOrange),
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.black.withOpacity(0.45),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _LocationBar extends StatelessWidget {
  final String leftText;
  final String rightText;
  final VoidCallback onTap;

  const _LocationBar({
    required this.leftText,
    required this.rightText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_rounded, color: HomePageV2Option2.prestoOrange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "$leftText  •  ",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              rightText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: HomePageV2Option2.prestoOrange,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}

class _ChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? HomePageV2Option2.prestoOrange : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? HomePageV2Option2.prestoOrange : Colors.black12,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _HeroCardOption2 extends StatelessWidget {
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onCta;

  const _HeroCardOption2({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          // Fond dégradé orange
          Container(
            height: 190,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFA36C),
                  HomePageV2Option2.prestoOrange,
                ],
              ),
            ),
          ),

          // Overlay sombre
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.35),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.95),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // CTA button (orange pill)
                  SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onCta,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: HomePageV2Option2.prestoOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        cta,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Subtle glass highlight
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  height: 30,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: HomePageV2Option2.prestoOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: HomePageV2Option2.textMuted,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final bool showChevron;

  const _StepCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.showChevron,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: HomePageV2Option2.prestoOrange,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              "$number",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: HomePageV2Option2.textMuted,
                    ),
                  ),
                ]
              ],
            ),
          ),
          if (showChevron)
            const Icon(Icons.chevron_right_rounded, color: Colors.black38),
        ],
      ),
    );
  }
}

/// Bottom bar Option 2 (accent orange + bouton Publier)
class _BottomNavOption2 extends StatelessWidget {
  final int currentIndex;
  const _BottomNavOption2({required this.currentIndex});

  static const items = [
    ("Accueil", Icons.home_rounded),
    ("Offres", Icons.search_rounded),
    ("Publier", Icons.add_rounded),
    ("Messages", Icons.chat_bubble_outline_rounded),
    ("Compte", Icons.person_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final active = i == currentIndex;
          final label = items[i].$1;
          final icon = items[i].$2;

          if (i == 2) {
            // Center publish FAB-like
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: HomePageV2Option2.prestoOrange,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: HomePageV2Option2.prestoOrange.withOpacity(0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Publier",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }

          return Expanded(
            child: InkWell(
              onTap: () {},
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: active
                        ? HomePageV2Option2.prestoOrange
                        : Colors.black45,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: active
                          ? HomePageV2Option2.prestoOrange
                          : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
