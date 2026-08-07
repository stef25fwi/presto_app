import 'package:flutter/material.dart';

import '../services/public_landing_config_service.dart';
import 'public_prelaunch_feature_sections.dart';
import 'public_prelaunch_footer.dart';
import 'public_prelaunch_header.dart';

class PublicPrelaunchContent extends StatelessWidget {
  const PublicPrelaunchContent({
    super.key,
    required this.config,
    required this.compact,
    required this.veryCompact,
    required this.onOpenPublicPage,
  });

  final PublicLandingConfigService config;
  final bool compact;
  final bool veryCompact;
  final Future<void> Function(String path) onOpenPublicPage;

  @override
  Widget build(BuildContext context) {
    final cardPadding = veryCompact ? 16.0 : compact ? 20.0 : 40.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        cardPadding,
        compact ? 20 : 32,
        cardPadding,
        compact ? 22 : 30,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(veryCompact ? 22 : 28),
        border: Border.all(color: const Color(0x1F1A73E8)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x160C315F),
            blurRadius: 34,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          PublicPrelaunchHeader(
            badge: config.badge,
            title: config.title,
            compact: compact,
            veryCompact: veryCompact,
          ),
          SizedBox(height: compact ? 18 : 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(
              config.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF526477),
                fontSize: veryCompact ? 15 : compact ? 16 : 18,
                height: 1.55,
              ),
            ),
          ),
          SizedBox(height: compact ? 26 : 34),
          const PublicPrelaunchFeatureGrid(),
          SizedBox(height: compact ? 24 : 30),
          PublicPrelaunchLaunchPanel(
            message: config.launchMessage,
            compact: compact,
          ),
          SizedBox(height: compact ? 24 : 30),
          const Divider(height: 1, color: Color(0xFFE5EAF0)),
          SizedBox(height: compact ? 16 : 20),
          PublicPrelaunchFooter(
            compact: compact,
            veryCompact: veryCompact,
            onOpen: onOpenPublicPage,
          ),
        ],
      ),
    );
  }
}
