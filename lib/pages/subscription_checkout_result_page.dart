import 'package:flutter/material.dart';

const _kPrestoOrange = Color(0xFFFF6600);

/// Écran affiché au retour du paiement Stripe Checkout (succès ou
/// annulation) — Stripe redirige vers `${APP_BASE_URL}/abonnement?checkout=success|cancel`.
/// L'activation réelle du plan est faite par le webhook côté serveur ; cet
/// écran ne fait qu'informer l'utilisateur, sans lire Stripe directement.
class SubscriptionCheckoutResultPage extends StatelessWidget {
  final bool success;

  const SubscriptionCheckoutResultPage({super.key, required this.success});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/logowebp.webp',
                    height: 88,
                  ),
                  const SizedBox(height: 28),
                  Icon(
                    success
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: success ? Colors.green.shade600 : _kPrestoOrange,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    success ? 'Merci !' : 'Paiement annulé',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    success
                        ? 'Votre paiement a bien été pris en compte. Votre formule iliprestō s’active en quelques secondes.'
                        : 'Le paiement a été annulé, aucun montant n’a été prélevé. Vous pouvez réessayer à tout moment depuis votre compte.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _kPrestoOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/account',
                          (route) => false,
                        );
                      },
                      child: const Text(
                        'Retour à mon compte',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
