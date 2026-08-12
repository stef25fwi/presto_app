import 'package:flutter/material.dart';

const String kPhoneVerificationDisclaimer =
    'Contrôle technique uniquement : ce badge confirme l’accès au numéro lors du contrôle SMS. Il ne constitue ni une approbation, ni une certification, ni une recommandation, ni une garantie d’iliprestō sur l’identité, la fiabilité ou les prestations de l’utilisateur.';

const String kSiretVerificationDisclaimer =
    'Contrôle administratif limité : ce badge indique que le SIRET correspondait à un établissement actif dans la source administrative consultée au moment du contrôle. Il ne constitue ni une approbation, ni une certification, ni une recommandation, ni une garantie d’iliprestō sur l’entreprise, le prestataire, ses compétences, ses assurances ou ses prestations.';

class VerificationStatusTooltip extends StatelessWidget {
  const VerificationStatusTooltip({
    super.key,
    required this.message,
    required this.child,
  });

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 7),
      child: Semantics(
        button: true,
        hint: 'Afficher la portée de cette vérification',
        child: child,
      ),
    );
  }
}
