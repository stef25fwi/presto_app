import 'package:flutter/material.dart';

/// États de repli (chargement / erreur) du slider média héro. Extrait de
/// `widgets/hero_media_slider.dart` pour rester sous le budget de lignes
/// d'un widget.
class HeroMediaLoadingFallback extends StatelessWidget {
  const HeroMediaLoadingFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF1A73E8),
        ),
      ),
    );
  }
}

class HeroMediaErrorFallback extends StatelessWidget {
  const HeroMediaErrorFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFF6600),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.white,
        size: 34,
      ),
    );
  }
}
