part of 'payment_info_popup.dart';

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
