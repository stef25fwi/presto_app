import 'package:flutter/material.dart';

class PublicPrelaunchHeader extends StatelessWidget {
  const PublicPrelaunchHeader({
    super.key,
    required this.badge,
    required this.title,
    required this.compact,
    required this.veryCompact,
    required this.statusKey,
  });

  final String badge;
  final String title;
  final bool compact;
  final bool veryCompact;
  final Key statusKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _TopBar(
          badge: badge,
          compact: compact,
          veryCompact: veryCompact,
          statusKey: statusKey,
        ),
        SizedBox(height: compact ? 28 : 40),
        _HeroTitle(title: title),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.badge,
    required this.compact,
    required this.veryCompact,
    required this.statusKey,
  });

  final String badge;
  final bool compact;
  final bool veryCompact;
  final Key statusKey;

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
          statusKey: statusKey,
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
    required this.statusKey,
    required this.label,
    required this.compact,
    required this.veryCompact,
  });

  final Key statusKey;
  final String label;
  final bool compact;
  final bool veryCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: statusKey,
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
