import 'package:flutter/material.dart';

import 'entrepreneur_pricing_form_shell_widgets.dart';

export 'entrepreneur_pricing_form_input_widgets.dart';
export 'entrepreneur_pricing_form_shell_widgets.dart';

/// Bouton d’entrée du parcours de calcul.
///
/// Il garde la présentation principale centralisée tout en permettant aux
/// écrans d’accueil de rester indépendants de l’implémentation interne.
class PricingStartButton extends StatelessWidget {
  const PricingStartButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PricingPrimaryButton(
      text: 'Commencer',
      icon: Icons.play_arrow_rounded,
      color: formOrange,
      onPressed: onPressed,
    );
  }
}