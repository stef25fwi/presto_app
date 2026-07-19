import 'dart:async';
import 'package:flutter/material.dart';
import 'package:presto_app/pages/legal_info_page.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';
import 'package:presto_app/widgets/payment_info_audio_player_button.dart';

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

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/logowebp.webp',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'iliprestō',
            style: TextStyle(
              color: Color(0xFFFF6600),
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F6FB),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.close_rounded, color: kBlueDark, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({this.audioUrl});

  final String? audioUrl;

  @override
  Widget build(BuildContext context) {
    final canPlay = audioUrl != null && audioUrl!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBD9FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canPlay) ...[
            SizedBox(
              width: double.infinity,
              child: PaymentInfoAudioPlayerButton(
                audioUrl: audioUrl!,
                label: "Écouter l'explication",
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: kBlue, size: 38),
              const SizedBox(width: 10),
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    text:
                        'La législation prévoit des règles différentes selon le statut du prestataire et le type de prestation.\n',
                    children: [
                      TextSpan(
                        text:
                            "Voici l'essentiel à retenir pour payer en toute sécurité.",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    color: kBlueDark,
                    fontSize: 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.number,
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
    required this.badgeIcon,
    required this.badge,
  });

  final String number;
  final Color color;
  final IconData icon;
  final String title;
  final String body;
  final IconData badgeIcon;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: color,
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          Icon(icon, color: color, size: 58),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 18,
              height: 1.12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kBlueDark,
                fontSize: 12.2,
                height: 1.22,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 78),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(badgeIcon, color: color, size: 26),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: kBlueDark,
                      fontSize: 11.5,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportantBox extends StatelessWidget {
  const _ImportantBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD18A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFC47A00), size: 40),
          SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Important : ',
                style: TextStyle(fontWeight: FontWeight.w900),
                children: [
                  TextSpan(
                    text:
                        'ilipresto.fr est un outil de communication et de petites annonces. La plateforme facilite la visibilité des offres et demandes, mais les relations, accords et prestations restent exclusivement conclus et gérés entre les utilisateurs.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              style: TextStyle(
                color: kBlueDark,
                fontSize: 13,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreInfoTile extends StatelessWidget {
  const _MoreInfoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: kTextSecondary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'En savoir plus sur les règles de paiement',
                style: TextStyle(
                  color: kBlueDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: kBlueDark),
          ],
        ),
      ),
    );
  }
}
