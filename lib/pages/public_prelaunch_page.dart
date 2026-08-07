import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/public_landing_config_service.dart';

class PublicPrelaunchPage extends StatefulWidget {
  const PublicPrelaunchPage({
    super.key,
    required this.config,
    this.onDeveloperAccessGranted,
  });

  static const accessTriggerKey = Key('public-prelaunch-access-trigger');
  static const developerAccessTapCount = 8;

  final PublicLandingConfigService config;
  final VoidCallback? onDeveloperAccessGranted;

  @override
  State<PublicPrelaunchPage> createState() => _PublicPrelaunchPageState();
}

class _PublicPrelaunchPageState extends State<PublicPrelaunchPage> {
  static const _tapSequenceTimeout = Duration(seconds: 8);
  static const _publicBaseUrl = 'https://ilipresto.fr';

  static const _footerLinks = <({String label, String path})>[
    (label: 'À propos', path: '/a-propos'),
    (
      label: 'Guide d’utilisation',
      path: '/guides/comment-fonctionne-ilipresto',
    ),
    (label: 'Mentions légales', path: '/mentions-legales'),
    (label: 'Confidentialité', path: '/confidentialite'),
    (label: 'CGU', path: '/cgu'),
    (label: 'Suppression du compte', path: '/suppression-compte'),
  ];

  Timer? _tapResetTimer;
  int _tapCount = 0;
  DateTime? _lastTapAt;
  bool _accessGranted = false;

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    super.dispose();
  }

  void _resetTapSequence() {
    if (_accessGranted || _tapCount == 0) return;
    _tapCount = 0;
    _lastTapAt = null;
  }

  void _handleStatusTap() {
    if (_accessGranted) return;

    final now = DateTime.now();
    final lastTapAt = _lastTapAt;
    final sequenceExpired = lastTapAt == null ||
        now.difference(lastTapAt) > _tapSequenceTimeout;
    final nextTapCount = sequenceExpired ? 1 : _tapCount + 1;

    _tapResetTimer?.cancel();

    if (nextTapCount >= PublicPrelaunchPage.developerAccessTapCount) {
      _accessGranted = true;
      _tapCount = PublicPrelaunchPage.developerAccessTapCount;
      _lastTapAt = now;
      widget.onDeveloperAccessGranted?.call();
      return;
    }

    _tapCount = nextTapCount;
    _lastTapAt = now;
    _tapResetTimer = Timer(_tapSequenceTimeout, _resetTapSequence);
  }

  Future<void> _openPublicPage(String path) async {
    final uri = Uri.parse('$_publicBaseUrl$path');
    final opened = await launchUrl(uri, webOnlyWindowName: '_self');
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir cette page pour le moment.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
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
                          GestureDetector(
                            key: PublicPrelaunchPage.accessTriggerKey,
                            behavior: HitTestBehavior.opaque,
                            onTap: _handleStatusTap,
                            child: Container(
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
                                            style: theme.textTheme.bodyMedium?.copyWith(
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
                          ),
                          const SizedBox(height: 22),
                          Semantics(
                            label: 'Liens publics et informations légales',
                            container: true,
                            child: Wrap(
                              key: const Key('public-prelaunch-footer-links'),
                              alignment: WrapAlignment.center,
                              runAlignment: WrapAlignment.center,
                              spacing: 4,
                              runSpacing: 2,
                              children: _footerLinks
                                  .map(
                                    (link) => TextButton(
                                      key: Key(
                                        'public-prelaunch-link-${link.path}',
                                      ),
                                      onPressed: () => _openPublicPage(link.path),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF175DB8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 7,
                                        ),
                                        minimumSize: const Size(44, 40),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        textStyle: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      child: Text(link.label),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                          const SizedBox(height: 12),
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
            child: Text.rich(
              const TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: 'ili',
                    style: TextStyle(color: Color(0xFF1A73E8)),
                  ),
                  TextSpan(
                    text: 'prestō',
                    style: TextStyle(color: Color(0xFFFF6600)),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: compact ? 32 : 40,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
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
