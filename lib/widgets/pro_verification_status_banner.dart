import 'package:flutter/material.dart';

import 'verification_status_tooltip.dart';

class ProVerificationStatusBanner extends StatelessWidget {
  const ProVerificationStatusBanner({
    super.key,
    required this.siretVerified,
    required this.leaderDeclaredMatch,
  });

  final bool siretVerified;
  final bool leaderDeclaredMatch;

  @override
  Widget build(BuildContext context) {
    final fullyMatched = siretVerified && leaderDeclaredMatch;
    final color = fullyMatched ? const Color(0xFF16A34A) : Colors.orange;
    final text = fullyMatched
        ? 'SIRET + dirigeant déclaré concordants.'
        : siretVerified
            ? 'SIRET validé — dirigeant déclaré à confirmer.'
            : 'Vérifiez le SIRET + dirigeant pour valider le profil professionnel.';

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(
            fullyMatched ? Icons.verified_rounded : Icons.warning_amber_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          if (fullyMatched) ...[
            const SizedBox(width: 6),
            Icon(Icons.info_outline_rounded, color: color, size: 18),
          ],
        ],
      ),
    );

    if (!fullyMatched) return content;
    return VerificationStatusTooltip(
      message: kSiretLeaderMatchDisclaimer,
      child: content,
    );
  }
}
