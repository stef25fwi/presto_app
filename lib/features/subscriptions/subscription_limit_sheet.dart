import 'package:flutter/material.dart';

import 'subscription_action_placeholders.dart';
import 'subscription_models.dart';

/// Bottom sheet réutilisable affichée quand un quota du plan Gratuit est
/// atteint (réponses aux annonces, favoris, IA annonce, photos, annonces
/// actives...). Reprend l'argument central "0 % de commission" et propose de
/// découvrir iliprestō+ — le paiement reste un placeholder tant que Stripe
/// n'est pas activé.
Future<void> showSubscriptionLimitSheet(
  BuildContext context, {
  required String message,
  required bool stripeEnabled,
  required String source,
  String targetPlanKey = 'ilipresto_plus',
  String discoverButtonLabel = 'Découvrir iliprestō+',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Text(
                'Limite atteinte',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                kSubscriptionZeroCommissionMessage,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6600),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    if (stripeEnabled) {
                      startSubscriptionCheckout(
                        context,
                        targetPlanKey,
                        stripeEnabled: stripeEnabled,
                        source: source,
                      );
                    } else {
                      notifySubscriptionLaunch(
                        context,
                        targetPlanKey,
                        stripeEnabled: stripeEnabled,
                        source: source,
                      );
                    }
                  },
                  child: Text(
                    discoverButtonLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
