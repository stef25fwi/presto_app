import 'package:flutter/material.dart';

import '../services/cookie_consent_service.dart';

const _orange = Color(0xFFFF5A00);
const _blue = Color(0xFF0B5BEA);
const _navy = Color(0xFF07153D);
const _border = Color(0xFFDDE3EE);
const _brandLogoAsset = 'assets/images/logowebp.webp';

class CookieConsentBanner extends StatelessWidget {
  const CookieConsentBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CookieConsentService.instance,
      builder: (context, child) {
        if (!CookieConsentService.instance.shouldShowBanner) {
          return const SizedBox.shrink();
        }

        final width = MediaQuery.sizeOf(context).width;
        final mobile = width < 720;
        return Positioned.fill(
          child: Material(
            color: Colors.black.withValues(alpha: mobile ? 0.42 : 0.26),
            child: SafeArea(
              minimum: EdgeInsets.fromLTRB(
                mobile ? 0 : 20,
                20,
                mobile ? 0 : 20,
                mobile ? 0 : 20,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: mobile
                    ? const _MobileConsentSheet()
                    : const _DesktopConsentBanner(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const _BrandMark(width: 156, height: 44);
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.width = 50, this.height = 50});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Logo iliprestō',
      child: Image.asset(
        _brandLogoAsset,
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _MobileConsentSheet extends StatelessWidget {
  const _MobileConsentSheet();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      elevation: 24,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3D6DC),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Align(alignment: Alignment.centerLeft, child: _Brand()),
              const SizedBox(height: 18),
              const Text(
                'Nous utilisons des cookies\npour améliorer votre expérience',
                style: TextStyle(
                  color: _navy,
                  fontSize: 22,
                  height: 1.18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.45,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Nous et nos partenaires utilisons des cookies et traitements similaires pour assurer le service, mesurer l’audience et personnaliser les contenus selon vos choix.',
                style: TextStyle(
                  color: Color(0xFF46516A),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              _PrimaryConsentButton(
                label: 'Accepter',
                onPressed: CookieConsentService.instance.acceptAll,
              ),
              const SizedBox(height: 9),
              _OutlineConsentButton(
                label: 'Refuser',
                onPressed: CookieConsentService.instance.refuseAll,
              ),
              const SizedBox(height: 9),
              _OutlineConsentButton(
                label: 'Gérer mes choix',
                blue: true,
                onPressed: () => showCookiePreferencesDialog(context),
              ),
              const SizedBox(height: 14),
              const _ComplianceChips(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopConsentBanner extends StatelessWidget {
  const _DesktopConsentBanner();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1120),
      child: Material(
        color: Colors.white,
        elevation: 24,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Row(
            children: [
              const _BrandMark(),
              const SizedBox(width: 18),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nous utilisons des cookies pour améliorer votre expérience',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Les traceurs non essentiels restent bloqués tant que vous n’avez pas exprimé votre choix.',
                      style: TextStyle(
                        color: Color(0xFF536078),
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              TextButton(
                onPressed: () => showCookiePreferencesDialog(context),
                child: const Text('Gérer mes choix'),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 124,
                child: _OutlineConsentButton(
                  label: 'Refuser',
                  onPressed: CookieConsentService.instance.refuseAll,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 138,
                child: _PrimaryConsentButton(
                  label: 'Accepter',
                  onPressed: CookieConsentService.instance.acceptAll,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryConsentButton extends StatelessWidget {
  const _PrimaryConsentButton({required this.label, required this.onPressed});

  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.check_circle, size: 18),
      label: Text(label),
    );
  }
}

class _OutlineConsentButton extends StatelessWidget {
  const _OutlineConsentButton({
    required this.label,
    required this.onPressed,
    this.blue = false,
  });

  final String label;
  final Future<void> Function() onPressed;
  final bool blue;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: blue ? _blue : _navy,
        side: BorderSide(color: blue ? _blue : const Color(0xFF9AA5B8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}

class _ComplianceChips extends StatelessWidget {
  const _ComplianceChips();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 7,
      runSpacing: 7,
      children: [
        _ComplianceChip(icon: Icons.verified_user_outlined, label: 'RGPD'),
        _ComplianceChip(icon: Icons.g_mobiledata, label: 'Consent Mode v2'),
        _ComplianceChip(icon: Icons.shield_outlined, label: 'TCF 2.3'),
      ],
    );
  }
}

class _ComplianceChip extends StatelessWidget {
  const _ComplianceChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _blue),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: _blue,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showCookiePreferencesDialog(BuildContext context) async {
  final current = CookieConsentService.instance.state;
  var analyticsAllowed = current?.analyticsAllowed ?? false;
  var preferencesAllowed = current?.marketingAllowed ?? false;
  var marketingAllowed = current?.marketingAllowed ?? false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const _Brand(),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Fermer',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Gérer mes préférences',
                        style: TextStyle(
                          color: _navy,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Vous pouvez modifier vos choix à tout moment. Les cookies essentiels restent toujours actifs.',
                        style: TextStyle(color: Color(0xFF536078), height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      const _PreferenceTile(
                        icon: Icons.shield_outlined,
                        title: 'Essentiels',
                        subtitle: 'Nécessaires au fonctionnement et à la sécurité du site.',
                        value: true,
                        locked: true,
                      ),
                      const SizedBox(height: 10),
                      _PreferenceTile(
                        icon: Icons.bar_chart_rounded,
                        title: 'Performance',
                        subtitle: 'Mesure l’audience et améliore la performance.',
                        value: analyticsAllowed,
                        onChanged: (value) =>
                            setState(() => analyticsAllowed = value),
                      ),
                      const SizedBox(height: 10),
                      _PreferenceTile(
                        icon: Icons.tune,
                        title: 'Préférences',
                        subtitle: 'Mémorise vos choix et personnalise votre expérience.',
                        value: preferencesAllowed,
                        onChanged: (value) =>
                            setState(() => preferencesAllowed = value),
                      ),
                      const SizedBox(height: 10),
                      _PreferenceTile(
                        icon: Icons.campaign_outlined,
                        title: 'Marketing',
                        subtitle: 'Autorise la publicité personnalisée et sa mesure.',
                        value: marketingAllowed,
                        onChanged: (value) =>
                            setState(() => marketingAllowed = value),
                      ),
                      const SizedBox(height: 22),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 520;
                          final actions = [
                            Expanded(
                              child: _OutlineConsentButton(
                                label: 'Tout refuser',
                                onPressed: () async {
                                  await CookieConsentService.instance.refuseAll();
                                  if (dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10, height: 10),
                            Expanded(
                              child: _PrimaryConsentButton(
                                label: 'Enregistrer',
                                onPressed: () async {
                                  await CookieConsentService.instance
                                      .savePreferences(
                                    analyticsAllowed: analyticsAllowed,
                                    marketingAllowed:
                                        marketingAllowed || preferencesAllowed,
                                  );
                                  if (dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                  }
                                },
                              ),
                            ),
                          ];
                          return compact
                              ? Column(
                                  children: [
                                    SizedBox(width: double.infinity, child: actions[0]),
                                    actions[1],
                                    SizedBox(width: double.infinity, child: actions[2]),
                                  ],
                                )
                              : Row(children: actions);
                        },
                      ),
                      const SizedBox(height: 14),
                      const _ComplianceChips(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.locked = false,
    this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool locked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF1FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF657087),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (locked)
            const Row(
              children: [
                Text(
                  'Toujours actifs',
                  style: TextStyle(
                    color: Color(0xFF647089),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 5),
                Icon(Icons.lock_outline, size: 16, color: Color(0xFF647089)),
              ],
            )
          else
            Switch(
              value: value,
              activeTrackColor: _blue,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}
