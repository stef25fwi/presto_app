import 'package:flutter/material.dart';

class PublicPrelaunchFeatureGrid extends StatelessWidget {
  const PublicPrelaunchFeatureGrid({super.key});

  static const _features = <({
    IconData icon,
    String title,
    String description,
    Color color,
  })>[
    (
      icon: Icons.auto_awesome_rounded,
      title: 'Annonces assistées par IA',
      description: 'Gagnez du temps, l’IA rédige pour vous.',
      color: Color(0xFF1A73E8),
    ),
    (
      icon: Icons.mic_rounded,
      title: 'Saisie texte ou vocale',
      description: 'Parlez ou écrivez, on s’occupe du reste.',
      color: Color(0xFFFF6600),
    ),
    (
      icon: Icons.percent_rounded,
      title: '0 % de commission',
      description: 'Échangez directement, sans frais.',
      color: Color(0xFF1A73E8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 300 ? 3 : 1;
        final gap = columns == 3 ? 10.0 : 12.0;
        final itemWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;
        final dense = columns == 3 && constraints.maxWidth < 520;

        return Wrap(
          alignment: WrapAlignment.center,
          spacing: gap,
          runSpacing: gap,
          children: _features.map((feature) {
            return SizedBox(
              width: itemWidth,
              child: _FeatureCard(
                icon: feature.icon,
                title: feature.title,
                description: feature.description,
                color: feature.color,
                dense: dense,
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class PublicPrelaunchLaunchPanel extends StatelessWidget {
  const PublicPrelaunchLaunchPanel({
    super.key,
    required this.message,
    required this.compact,
  });

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 18,
        vertical: compact ? 16 : 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(18),
        border: const Border(
          left: BorderSide(color: Color(0xFFFF6600), width: 5),
          top: BorderSide(color: Color(0x55FF6600)),
          right: BorderSide(color: Color(0x55FF6600)),
          bottom: BorderSide(color: Color(0x55FF6600)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: compact ? 40 : 46,
            height: compact ? 40 : 46,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEEE2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: const Color(0xFFFF6600),
              size: compact ? 24 : 28,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              message,
              textAlign: TextAlign.start,
              style: TextStyle(
                color: const Color(0xFF6F370F),
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.dense,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: dense ? 176 : 160),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 16,
        vertical: dense ? 13 : 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E8EF)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: dense ? 40 : 50,
            height: dense ? 40 : 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: dense ? 22 : 27, color: color),
          ),
          SizedBox(height: dense ? 10 : 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF203B5A),
              fontSize: dense ? 11.5 : 14,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          SizedBox(height: dense ? 7 : 9),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF5D6D7E),
              fontSize: dense ? 10 : 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
