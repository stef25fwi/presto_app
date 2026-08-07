import 'package:flutter/material.dart';

import '../services/public_landing_config_service.dart';
import 'public_prelaunch_feature_sections.dart';

class PublicPrelaunchContent extends StatelessWidget {
  const PublicPrelaunchContent({
    super.key,
    required this.config,
    required this.compact,
    required this.veryCompact,
    required this.onOpenPublicPage,
  });

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
          _TopBar(
            badge: config.badge,
            compact: compact,
            veryCompact: veryCompact,
          ),
          SizedBox(height: compact ? 28 : 40),
          _HeroTitle(title: config.title),
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
          _FooterLinks(
            compact: compact,
            links: _footerLinks,
            onOpen: onOpenPublicPage,
          ),
          const SizedBox(height: 18),
          Text(
            'ilipresto.fr',
            style: TextStyle(
              color: const Color(0xFF6A7785),
              fontSize: veryCompact ? 13 : 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.badge,
    required this.compact,
    required this.veryCompact,
  });

  final String badge;
  final bool compact;
  final bool veryCompact;

  @override
  Widget build(BuildContext context) {
    final logoSize = veryCompact ? 40.0 : compact ? 46.0 : 58.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Semantics(
            label: 'iliprestō',
            header: true,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: logoSize,
                  height: logoSize,
                  child: Image.asset(
                    'assets/images/ilipresto_splash_logo.webp',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A73E8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.handshake_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: veryCompact ? 7 : 10),
                Flexible(
                  child: Text(
                    'iliprestō',
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: veryCompact ? 22 : compact ? 26 : 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: const Color(0xFFFF6600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _StatusBadge(
          label: badge,
          compact: compact,
          veryCompact: veryCompact,
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.compact,
    required this.veryCompact,
  });

  final String label;
  final bool compact;
  final bool veryCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: veryCompact ? 112 : 150),
      padding: EdgeInsets.symmetric(
        horizontal: veryCompact ? 9 : compact ? 11 : 14,
        vertical: veryCompact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x221A73E8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: veryCompact ? 6 : 8,
            height: veryCompact ? 6 : 8,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF1A73E8),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: veryCompact ? 5 : 8),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF175DB8),
                fontWeight: FontWeight.w800,
                fontSize: veryCompact ? 10 : compact ? 11 : 13,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle({required this.title});

  static const _highlightedWords = 'près de chez vous';
  final String title;

  @override
  Widget build(BuildContext context) {
    final index = title.toLowerCase().lastIndexOf(_highlightedWords);
    final width = MediaQuery.sizeOf(context).width;
    final baseStyle = TextStyle(
      color: const Color(0xFF12345B),
      fontSize: width < 350 ? 27 : width < 600 ? 31 : 46,
      fontWeight: FontWeight.w800,
      height: 1.12,
      letterSpacing: -0.8,
    );

    if (index < 0) {
      return Text(
        title,
        key: const Key('public-prelaunch-title'),
        textAlign: TextAlign.center,
        style: baseStyle,
      );
    }

    return Semantics(
      header: true,
      label: title,
      child: ExcludeSemantics(
        child: Text.rich(
          key: const Key('public-prelaunch-title'),
          TextSpan(
            style: baseStyle,
            children: <InlineSpan>[
              TextSpan(text: '${title.substring(0, index).trimRight()}\n'),
              TextSpan(
                text: title.substring(index),
                style: const TextStyle(
                  color: Color(0xFFFF6600),
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFFFF6600),
                  decorationThickness: 2.5,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks({
    required this.compact,
    required this.links,
    required this.onOpen,
  });

  final bool compact;
  final List<({String label, String path})> links;
  final Future<void> Function(String path) onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Liens publics et informations légales',
      container: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = compact ? 2 : 3;
          const gap = 6.0;
          final itemWidth =
              (constraints.maxWidth - (gap * (columns - 1))) / columns;

          return Wrap(
            key: const Key('public-prelaunch-footer-links'),
            spacing: gap,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: links.map((link) {
              return SizedBox(
                width: itemWidth,
                child: TextButton(
                  key: Key('public-prelaunch-link-${link.path}'),
                  onPressed: () => onOpen(link.path),
                  style: TextButton.styleFrom(
                    alignment: Alignment.center,
                    foregroundColor: const Color(0xFF175DB8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    minimumSize: const Size(44, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: TextStyle(
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationThickness: 1,
                    ),
                  ),
                  child: Text(link.label, textAlign: TextAlign.center),
                ),
              );
            }).toList(growable: false),
          );
        },
      ),
    );
  }
}
