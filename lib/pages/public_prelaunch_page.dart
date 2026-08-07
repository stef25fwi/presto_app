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
    final sequenceExpired = _lastTapAt == null ||
        now.difference(_lastTapAt!) > _tapSequenceTimeout;
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
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;
    final veryCompact = width < 350;
    final outerPadding = veryCompact ? 12.0 : compact ? 16.0 : 32.0;
    final cardPadding = veryCompact ? 16.0 : compact ? 20.0 : 40.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFFFFFFF),
              Color(0xFFF8FAFD),
              Color(0xFFF2F7FF),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  outerPadding,
                  compact ? 16 : 28,
                  outerPadding,
                  compact ? 20 : 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: viewport.maxHeight - (compact ? 36 : 60),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: GestureDetector(
                        key: PublicPrelaunchPage.accessTriggerKey,
                        behavior: HitTestBehavior.opaque,
                        onTap: _handleStatusTap,
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(
                            cardPadding,
                            compact ? 20 : 32,
                            cardPadding,
                            compact ? 22 : 30,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              veryCompact ? 22 : 28,
                            ),
                            border: Border.all(
                              color: const Color(0x1F1A73E8),
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
                              _buildTopBar(compact, veryCompact),
                              SizedBox(height: compact ? 28 : 40),
                              _buildTitle(context),
                              SizedBox(height: compact ? 18 : 22),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 720),
                                child: Text(
                                  widget.config.description,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFF526477),
                                    fontSize: veryCompact
                                        ? 15
                                        : compact
                                            ? 16
                                            : 18,
                                    height: 1.55,
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 26 : 34),
                              _buildFeatures(),
                              SizedBox(height: compact ? 24 : 30),
                              _buildLaunchPanel(compact),
                              SizedBox(height: compact ? 24 : 30),
                              const Divider(
                                height: 1,
                                color: Color(0xFFE5EAF0),
                              ),
                              SizedBox(height: compact ? 16 : 20),
                              _buildFooterLinks(compact),
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
                        ),
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

  Widget _buildTopBar(bool compact, bool veryCompact) {
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
        Container(
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
                  widget.config.badge,
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
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    const highlightedWords = 'près de chez vous';
    final title = widget.config.title;
    final index = title.toLowerCase().lastIndexOf(highlightedWords);
    final width = MediaQuery.sizeOf(context).width;
    final baseStyle = TextStyle(
      color: const Color(0xFF12345B),
      fontSize: width < 350
          ? 27
          : width < 600
              ? 31
              : 46,
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

  Widget _buildFeatures() {
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
              child: Container(
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
                        color: feature.color.withValues(alpha: 0.11),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        feature.icon,
                        size: dense ? 22 : 27,
                        color: feature.color,
                      ),
                    ),
                    SizedBox(height: dense ? 10 : 14),
                    Text(
                      feature.title,
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
                      feature.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF5D6D7E),
                        fontSize: dense ? 10 : 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }

  Widget _buildLaunchPanel(bool compact) {
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
              widget.config.launchMessage,
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

  Widget _buildFooterLinks(bool compact) {
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
            children: _footerLinks.map((link) {
              return SizedBox(
                width: itemWidth,
                child: TextButton(
                  key: Key('public-prelaunch-link-${link.path}'),
                  onPressed: () => _openPublicPage(link.path),
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
                  child: Text(
                    link.label,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }).toList(growable: false),
          );
        },
      ),
    );
  }
}
