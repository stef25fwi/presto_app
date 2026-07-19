part of 'payment_info_popup.dart';

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
