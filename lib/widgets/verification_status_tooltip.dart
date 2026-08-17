import 'package:flutter/material.dart';

const String kPhoneVerificationDisclaimer =
    'Contrôle technique uniquement : ce badge confirme l’accès au numéro lors du contrôle SMS. Il ne constitue ni une approbation, ni une certification, ni une recommandation, ni une garantie d’iliprestō sur l’identité, la fiabilité ou les prestations de l’utilisateur.';

const String kSiretVerificationDisclaimer =
    'Contrôle administratif limité : ce badge indique que le SIRET correspondait à un établissement actif dans la source administrative consultée au moment du contrôle. Il ne constitue ni une approbation, ni une certification, ni une recommandation, ni une garantie d’iliprestō sur l’entreprise, le prestataire, ses compétences, ses assurances ou ses prestations.';

const String kSiretLeaderMatchDisclaimer =
    'Concordance administrative limitée : le SIRET correspondait à un établissement actif et le nom/prénom du dirigeant déclaré concordaient avec un dirigeant personne physique dans la source administrative consultée. Ce contrôle ne prouve pas que la personne connectée est ce dirigeant et ne constitue ni une approbation, ni une certification, ni une recommandation, ni une garantie d’iliprestō.';

class VerificationStatusTooltip extends StatelessWidget {
  const VerificationStatusTooltip({
    super.key,
    required this.message,
    required this.child,
  });

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
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

class VerificationStatusBadge extends StatelessWidget {
  const VerificationStatusBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.message,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;
  final String message;

  @override
  Widget build(BuildContext context) => VerificationStatusTooltip(
        message: message,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.info_outline_rounded, size: 13, color: color),
            ],
          ),
        ),
      );
}
