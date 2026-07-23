import 'package:flutter/material.dart';

class AdminVideoMakerTile extends StatelessWidget {
  final VoidCallback onTap;

  const AdminVideoMakerTile({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF6600);
    const text = Color(0xFF111827);
    const muted = Color(0xFF6B7280);
    const border = Color(0xFFE5E7EB);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: const Row(
            children: [
              _VideoMakerIcon(),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Videomaker',
                      style: TextStyle(
                        color: text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Créer des vidéos VEO depuis un prompt et une image.',
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoMakerIcon extends StatelessWidget {
  const _VideoMakerIcon();

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF6600);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const SizedBox(
        width: 48,
        height: 48,
        child: Icon(Icons.movie_creation_outlined, color: accent),
      ),
    );
  }
}
