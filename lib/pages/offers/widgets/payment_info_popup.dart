import 'dart:async';

import 'package:flutter/material.dart';
import 'package:presto_app/pages/legal_info_page.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';
import 'package:presto_app/widgets/payment_info_audio_player_button.dart';

part 'payment_info_popup_header.dart';
part 'payment_info_popup_rules.dart';

const Color kBlueDark = Color(0xFF07184A);
const Color kBlue = Color(0xFF0A7BFF);
const Color kOrange = Color(0xFFFF8A00);
const Color kGreen = Color(0xFF16A05D);
const Color kPurple = Color(0xFF6A4FD8);
const Color kBorder = Color(0xFFE2E8F0);
const Color kTextSecondary = Color(0xFF4A5878);

Future<bool?> showPaymentInfoPopup(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const PaymentInfoPopup(),
  );
}

class PaymentInfoPopup extends StatefulWidget {
  const PaymentInfoPopup({super.key});

  @override
  State<PaymentInfoPopup> createState() => _PaymentInfoPopupState();
}

class _PaymentInfoPopupState extends State<PaymentInfoPopup> {
  StreamSubscription<PaymentInfoAudioConfig?>? _configSub;
  PaymentInfoAudioConfig? _audioConfig;

  @override
  void initState() {
    super.initState();
    _configSub = PaymentInfoAudioService().watchConfig().listen((config) {
      if (mounted) setState(() => _audioConfig = config);
    });
  }

  @override
  void dispose() {
    _configSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: size.height * 0.92,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              children: [
                _Header(onClose: () => Navigator.of(context).pop(false)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                    child: Column(
                      children: [
                        const Text(
                          'Avant de payer une prestation',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: kBlueDark,
                            fontSize: 30,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.9,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Comprendre les moyens de paiement autorisés\net les règles à respecter',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: kTextSecondary,
                            fontSize: 16,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _InfoBanner(
                          audioUrl: _audioConfig?.canPlay == true
                              ? _audioConfig!.audioUrl
                              : null,
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.387,
                          children: const [
                            _RuleCard(
                              number: '1',
                              color: kGreen,
                              icon: Icons.storefront_rounded,
                              title: 'Prestation avec\nun professionnel',
                              body:
                                  'Le paiement doit pouvoir être justifié. Le prestataire peut remettre une facture ou un justificatif de paiement.',
                              badgeIcon: Icons.payments_rounded,
                              badge:
                                  'Paiement en espèces\nlimité à 1 000 €\nlorsque le payeur a son\ndomicile fiscal en France.',
                            ),
                            _RuleCard(
                              number: '2',
                              color: kOrange,
                              icon: Icons.handshake_rounded,
                              title: 'Prestation\nentre particuliers',
                              body:
                                  "Le paiement en espèces est possible lorsqu'il ne s'agit pas d'un besoin professionnel.",
                              badgeIcon: Icons.receipt_long_rounded,
                              badge:
                                  'Preuve écrite\nnécessaire au-delà de\n1 500 €',
                            ),
                            _RuleCard(
                              number: '3',
                              color: kPurple,
                              icon: Icons.home_work_rounded,
                              title: 'Services à la personne\nà domicile',
                              body:
                                  'Pour certaines activités (ménage, jardinage, aide à la personne, soutien scolaire...), le particulier peut utiliser le CESU.',
                              badgeIcon: Icons.badge_rounded,
                              badge:
                                  "Le CESU permet de\ndéclarer et rémunérer\nl'intervenant.",
                            ),
                            _RuleCard(
                              number: '4',
                              color: kBlue,
                              icon: Icons.verified_user_rounded,
                              title: 'Pour plus\nde sécurité',
                              body:
                                  'Privilégiez toujours un paiement traçable pour protéger le client comme le prestataire en cas de litige.',
                              badgeIcon: Icons.description_rounded,
                              badge:
                                  'Carte bancaire, virement,\npaiement sécurisé ou\nreçu écrit recommandés.',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const _ImportantBox(),
                        const SizedBox(height: 10),
                        _MoreInfoTile(onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const LegalInfoPage(initialTab: 2),
                            ),
                          );
                        }),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).pop(true),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text("J'ai compris"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
