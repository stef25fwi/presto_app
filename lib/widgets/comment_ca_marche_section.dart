import 'package:flutter/material.dart';

class CommentCaMarcheSection extends StatelessWidget {
  const CommentCaMarcheSection({
    super.key,
    required this.onChercheQuelquUn,
    required this.onChercheUnJob,
  });

  final VoidCallback onChercheQuelquUn;
  final VoidCallback onChercheUnJob;

  static const prestoBlue = Color(0xFF1A73E8);
  static const prestoOrange = Color(0xFFFF6600);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isNarrow = w < 420;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BrushTitle(
            text: 'Comment ça marche ?',
            brushColor: prestoOrange,
            textColor: Colors.white,
          ),
          const SizedBox(height: 12),

          // 2 cartes côte à côte (ou empilées si écran étroit)
          if (!isNarrow)
            Row(
              children: [
                Expanded(
                  child: _HowCard(
                    themeColor: prestoBlue,
                    title: 'Je cherche quelqu’un',
                    leadingIcon: Icons.search,
                    items: const [
                      _HowItem(
                        icon: Icons.description_outlined,
                        title: 'Publier',
                        subtitle: 'ma demande',
                      ),
                      _HowItem(
                        icon: Icons.notifications_active_outlined,
                        title: 'Recevoir',
                        subtitle: 'alertes',
                      ),
                      _HowItem(
                        icon: Icons.verified_outlined,
                        title: 'Choisir',
                        subtitle: 'prestataire',
                      ),
                    ],
                    ctaText: 'Je cherche quelqu’un',
                    onTap: onChercheQuelquUn,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HowCard(
                    themeColor: prestoOrange,
                    title: 'Je cherche un job',
                    leadingIcon: Icons.work_outline,
                    items: const [
                      _HowItem(
                        icon: Icons.place_outlined,
                        title: 'Voir les',
                        subtitle: 'offres',
                      ),
                      _HowItem(
                        icon: Icons.flash_on_outlined,
                        title: 'Postuler',
                        subtitle: 'en 1 clic',
                      ),
                      _HowItem(
                        icon: Icons.handshake_outlined,
                        title: 'Commencer',
                        subtitle: 'à travailler',
                      ),
                    ],
                    ctaText: 'Je cherche un job',
                    onTap: onChercheUnJob,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _HowCard(
                  themeColor: prestoBlue,
                  title: 'Je cherche quelqu’un',
                  leadingIcon: Icons.search,
                  items: const [
                    _HowItem(
                      icon: Icons.description_outlined,
                      title: 'Publier',
                      subtitle: 'ma demande',
                    ),
                    _HowItem(
                      icon: Icons.notifications_active_outlined,
                      title: 'Recevoir',
                      subtitle: 'alertes',
                    ),
                    _HowItem(
                      icon: Icons.verified_outlined,
                      title: 'Choisir',
                      subtitle: 'prestataire',
                    ),
                  ],
                  ctaText: 'Je cherche quelqu’un',
                  onTap: onChercheQuelquUn,
                ),
                const SizedBox(height: 12),
                _HowCard(
                  themeColor: prestoOrange,
                  title: 'Je cherche un job',
                  leadingIcon: Icons.work_outline,
                  items: const [
                    _HowItem(
                      icon: Icons.place_outlined,
                      title: 'Voir les',
                      subtitle: 'offres',
                    ),
                    _HowItem(
                      icon: Icons.flash_on_outlined,
                      title: 'Postuler',
                      subtitle: 'en 1 clic',
                    ),
                    _HowItem(
                      icon: Icons.handshake_outlined,
                      title: 'Commencer',
                      subtitle: 'à travailler',
                    ),
                  ],
                  ctaText: 'Je cherche un job',
                  onTap: onChercheUnJob,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BrushTitle extends StatelessWidget {
  const _BrushTitle({
    required this.text,
    required this.brushColor,
    required this.textColor,
  });

  final String text;
  final Color brushColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    // Brush “texturé” approximé : dégradé + léger grain via opacité
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            brushColor.withOpacity(0.95),
            brushColor.withOpacity(0.75),
            brushColor.withOpacity(0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 28,
            height: 1.0,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _HowCard extends StatelessWidget {
  const _HowCard({
    required this.themeColor,
    required this.title,
    required this.leadingIcon,
    required this.items,
    required this.ctaText,
    required this.onTap,
  }) : assert(items.length == 3);

  final Color themeColor;
  final String title;
  final IconData leadingIcon;
  final List<_HowItem> items;
  final String ctaText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bandeau haut (fond couleur, texte blanc)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              color: themeColor,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(leadingIcon, color: themeColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Corps blanc (icônes + libellés)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                      child: _StepBlock(color: themeColor, item: items[0])),
                  const _ArrowSep(),
                  Expanded(
                      child: _StepBlock(color: themeColor, item: items[1])),
                  const _ArrowSep(),
                  Expanded(
                      child: _StepBlock(color: themeColor, item: items[2])),
                ],
              ),
            ),

            // Bandeau bas (fond couleur, texte blanc)
            Material(
              color: themeColor,
              child: InkWell(
                onTap: onTap,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      ctaText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrowSep extends StatelessWidget {
  const _ArrowSep();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Icon(
        Icons.chevron_right,
        color: Colors.grey.withOpacity(0.35),
        size: 22,
      ),
    );
  }
}

class _StepBlock extends StatelessWidget {
  const _StepBlock({required this.color, required this.item});

  final Color color;
  final _HowItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(item.icon, color: color, size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          item.title,
          style: const TextStyle(
            color: Color(0xFF0D1B2A),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          item.subtitle,
          style: TextStyle(
            color: const Color(0xFF0D1B2A).withOpacity(0.75),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _HowItem {
  const _HowItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}
