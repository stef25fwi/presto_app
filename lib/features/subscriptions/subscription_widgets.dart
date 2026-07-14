import 'package:flutter/material.dart';

import '../../pages/admin_videomaker_page.dart';
import 'subscription_config_service.dart';
import 'subscription_widgets_base.dart' as base;

export 'subscription_widgets_base.dart' hide AdminSubscriptionTile;

class AdminSubscriptionTile extends StatelessWidget {
  final SubscriptionConfigService? service;

  const AdminSubscriptionTile({super.key, this.service});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        base.AdminSubscriptionTile(service: service),
        const SizedBox(height: 14),
        _AdminVideoMakerTile(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminVideoMakerPage(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AdminVideoMakerTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AdminVideoMakerTile({required this.onTap});

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
