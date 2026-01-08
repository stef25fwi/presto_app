import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:presto_app/pages/toolbox_page.dart';

class EntrepreneurToolboxSlide extends StatefulWidget {
  const EntrepreneurToolboxSlide({super.key});

  @override
  State<EntrepreneurToolboxSlide> createState() =>
      _EntrepreneurToolboxSlideState();
}

class _EntrepreneurToolboxSlideState extends State<EntrepreneurToolboxSlide> {
  // Couleurs Prestō
  static const prestoOrange = Color(0xFFFF6600);
  static const prestoBlue = Color(0xFF1A73E8);

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(26);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ToolboxPage(),
          ),
        );
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.985 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: border,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ToolboxPage(),
                ),
              );
            },
            child: Ink(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: border,
                image: const DecorationImage(
                  image: AssetImage('assets/carousel_home/backgroungslide.png'),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: border,
                child: Stack(
                  children: [
                    // ===== Décors bulles / bokeh (premium) =====
                    Positioned(
                      right: -52,
                      top: -55,
                      child: _softCircle(
                        170,
                        Colors.white.withOpacity(0.12),
                      ),
                    ),
                    Positioned(
                      right: 18,
                      bottom: -70,
                      child: _softCircle(
                        190,
                        prestoBlue.withOpacity(0.16),
                      ),
                    ),
                    Positioned(
                      left: -35,
                      bottom: -55,
                      child: _softCircle(
                        150,
                        Colors.white.withOpacity(0.10),
                      ),
                    ),
                    Positioned(
                      left: 120,
                      top: 22,
                      child: _softCircle(
                        18,
                        Colors.white.withOpacity(0.20),
                      ),
                    ),
                    Positioned(
                      left: 170,
                      top: 52,
                      child: _softCircle(
                        10,
                        Colors.white.withOpacity(0.18),
                      ),
                    ),

                    // ===== Contenu =====
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          // Texte + CTA
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Chips PRO + Nouveau
                                Row(
                                  children: [
                                    _chip(
                                      "PRO",
                                      bg: Colors.white.withOpacity(0.18),
                                      fg: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    _chip(
                                      "Nouveau",
                                      bg: Colors.white,
                                      fg: prestoOrange,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                const Text(
                                  "Boîte à outils de\nl'entrepreneur",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                    letterSpacing: -0.2,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                Text(
                                  "CCI, Région, aides, statuts, subventions...\nTout pour avancer vite.",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.88),
                                    fontSize: 13.6,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                const Spacer(),

                                // CTA "Découvrir"
                                _ctaDiscoverButton(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const ToolboxPage(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 14),

                          // Icône info à droite (rond + halo)
                          _infoIcon(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===== Widgets UI =====

  Widget _ctaDiscoverButton({required VoidCallback onTap}) {
    final r = BorderRadius.circular(999);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: r,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: r,
            // Effet "glass" léger
            color: Colors.white.withOpacity(0.18),
            border: Border.all(color: Colors.white.withOpacity(0.26)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // petit pictogramme "crown"
              Icon(Icons.workspace_premium_rounded,
                  size: 18, color: Colors.white.withOpacity(0.95)),
              const SizedBox(width: 8),
              const Text(
                "Découvrir",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward_rounded,
                  size: 18, color: Colors.white.withOpacity(0.92)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Halo
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.16),
            border: Border.all(color: Colors.white.withOpacity(0.22), width: 2),
          ),
        ),
        // Cercle blanc interne
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.92),
          ),
        ),
        // Cercle bleu + icône "i"
        Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: prestoBlue,
          ),
          child: const Center(
            child: Icon(
              Icons.info_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _softCircle(double size, Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
