import 'package:flutter/material.dart';

import '../services/public_landing_config_service.dart';

class PublicPrelaunchPage extends StatelessWidget {
  const PublicPrelaunchPage({
    super.key,
    required this.config,
  });

  final PublicLandingConfigService config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 420;
    final horizontalPadding = compact ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF4EC),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFFFF8F2),
              Color(0xFFFDF4EC),
              Color(0xFFF5F9FF),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  24,
                  horizontalPadding,
                  28,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 52,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _BrandHeader(compact: compact),
                          const SizedBox(height: 30),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(compact ? 22 : 36),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: const Color(0x1A1A73E8),
                              ),
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
                                _StatusBadge(label: config.badge),
                                const SizedBox(height: 20),
                                Text(
                                  config.title,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    color: const Color(0xFF12345B),
                                    fontWeight: FontWeight.w800,
                                    height: 1.12,
                                    letterSpacing: -0.7,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  config.description,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: const Color(0xFF526477),
                                    height: 1.55,
                                  ),
                                ),
                                const SizedBox(height: 26),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: <Widget>[
                                    _FeatureChip(
                                      icon: Icons.auto_awesome_rounded,
                                      label: 'Annonces assistées par IA',
                                      expanded: compact,
                                    ),
                                    _FeatureChip(
                                      icon: Icons.record_voice_over_rounded,
                                      label: 'Saisie texte ou vocale',
                                      expanded: compact,
                                    ),
                                    _FeatureChip(
                                      icon: Icons.percent_rounded,
                                      label: '0 % de commission',
                                      expanded: compact,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 15,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E8),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.rocket_launch_rounded,
                                        size: 20,
                                        color: Color(0xFFFF6600),
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          config.launchMessage,
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: const Color(0xFF7A3A0D),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'ilipresto.fr',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6A7785),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'iliprestō',
      header: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: compact ? 64 : 76,
            height: compact ? 64 : 76,
            child: Image.asset(
              'assets/images/ilipresto_splash_logo.webp',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.handshake_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              'iliprestō',
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: compact ? 32 : 40,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
                color: const Color(0xFFFF6600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const SizedBox(
            width: 8,
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF1A73E8),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF175DB8),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.expanded,
  });

  final IconData icon;
  final String label;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      textAlign: expanded ? TextAlign.center : TextAlign.start,
      style: const TextStyle(
        color: Color(0xFF33485E),
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );

    return Container(
      width: expanded ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5EAF0)),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment:
            expanded ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: const Color(0xFF1A73E8)),
          const SizedBox(width: 8),
          if (expanded) Expanded(child: labelWidget) else labelWidget,
        ],
      ),
    );
  }
}
