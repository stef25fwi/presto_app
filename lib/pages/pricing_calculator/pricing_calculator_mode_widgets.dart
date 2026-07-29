part of '../pricing_calculator_page.dart';

class _ModeScopeBanner extends StatelessWidget {
  final PricingMode mode;

  const _ModeScopeBanner({required this.mode});

  @override
  Widget build(BuildContext context) {
    final expert = mode == PricingMode.expert;
    final color = expert ? const Color(0xFF0F4C81) : kPrestoBlue;
    final items = expert
        ? const [
            'Tous les calculs Standard',
            'Énergie, eau, transport et territoire',
            'Marché, scénarios, historique et PDF',
          ]
        : const [
            'Coûts directs et temps de travail',
            'Charges fixes et amortissement',
            'Prix minimum, prix conseillé et alerte de perte',
          ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            expert ? 'Ce mode ajoute' : 'Ce mode comprend',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, size: 17, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineHelp extends StatelessWidget {
  final String text;

  const _InlineHelp({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 17, color: Colors.black45),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

