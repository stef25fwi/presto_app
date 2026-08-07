import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/public_landing_config_service.dart';
import '../widgets/public_prelaunch_content.dart';

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
                        child: PublicPrelaunchContent(
                          config: widget.config,
                          compact: compact,
                          veryCompact: veryCompact,
                          onOpenPublicPage: _openPublicPage,
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
}
