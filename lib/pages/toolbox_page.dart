import 'package:flutter/material.dart';

import 'package:presto_app/pages/toolbox_hub_page.dart';

const Color kOrangeStart = Color(0xFFFF7A00);
const Color kOrangeEnd = Color(0xFFFF3D00);

const Color kBlueStart = Color(0xFF16A7FF);
const Color kBlueEnd = Color(0xFF002BD9);

const Color kTextDark = Color(0xFF050B1E);
const Color kTextGrey = Color(0xFF3E4554);
const Color kBlueText = Color(0xFF0872E8);

const Color kGreenCheck = Color(0xFF18B66A);

const Color kPageBackground = Color(0xFFF5F6F8);
const Color kCardBackground = Color(0xFFFFFFFF);
const Color kIconOrangeBg = Color(0xFFFFEEE6);
const Color kIconBlueBg = Color(0xFFEAF3FF);
const double kToolboxOuterPadding = 12;

class ToolboxPage extends StatelessWidget {
  const ToolboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ToolboxView();
  }
}

class _ToolboxView extends StatelessWidget {
  const _ToolboxView();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final shouldConstrain = width > 420;

    return Scaffold(
      backgroundColor: kPageBackground,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const _ToolboxHeader(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isShort = constraints.maxHeight < 760;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      kToolboxOuterPadding,
                      22,
                      kToolboxOuterPadding,
                      24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: shouldConstrain ? 430 : double.infinity,
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: _ToolboxCard(
                                icon: const Icon(
                                  Icons.rocket_launch_rounded,
                                  size: 42,
                                  color: Color(0xFFFF5A00),
                                ),
                                iconBackground: kIconOrangeBg,
                                title: 'CRÉER MON\nENTREPRISE',
                                subtitle: 'iliprestō me guide pas à pas.',
                                description:
                                    'Décris ton projet, ta situation et ton territoire pour obtenir des conseils concrets.',
                                benefits: const [
                                  'Statut juridique\nconseillé',
                                  'Coûts & démarches\nexactes',
                                  'Aides, subventions &\norganismes',
                                  'Plan d’action sur 30\njours',
                                ],
                                buttonLabel: 'Démarrer mon projet',
                                buttonGradient: const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    kBlueStart,
                                    kBlueEnd,
                                  ],
                                ),
                                onTap: _openCreateBusiness,
                                compact: isShort,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Expanded(
                              child: _ToolboxCard(
                                icon: const Icon(
                                  Icons.calculate_rounded,
                                  size: 44,
                                  color: Color(0xFF096FE8),
                                ),
                                iconBackground: kIconBlueBg,
                                title: 'FIXER MON PRIX\nDE VENTE',
                                subtitle: 'Je calcule un prix rentable.',
                                description:
                                    'En quelques clics, j’estime mon coût de revient, mes charges et mon positionnement marché.',
                                benefits: const [
                                  'Matières premières',
                                  'Temps de travail',
                                  'Charges & frais réels',
                                  'Positionnement face à\nla concurrence',
                                ],
                                buttonLabel: 'Calculer mon prix',
                                buttonGradient: const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Color(0xFFFF9800),
                                    Color(0xFFFF2F00),
                                  ],
                                ),
                                onTap: _openPriceCalculator,
                                compact: isShort,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _openCreateBusiness(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const CurrentToolboxPage()),
  );
}

void _openPriceCalculator(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const EntrepreneurCalculatorPage()),
  );
}

class _ToolboxHeader extends StatelessWidget {
  const _ToolboxHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      width: double.infinity,
      padding: const EdgeInsets.only(top: 34),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kOrangeStart,
            kOrangeEnd,
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 18,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).maybePop();
              },
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const Text(
            'Boîte à outils',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.0,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolboxCard extends StatelessWidget {
  final Widget icon;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final String description;
  final List<String> benefits;
  final String buttonLabel;
  final Gradient buttonGradient;
  final ValueChanged<BuildContext>? onTap;
  final bool compact;

  const _ToolboxCard({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.benefits,
    required this.buttonLabel,
    required this.buttonGradient,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 370;
    final useCompact = isCompact || compact;
    final horizontalPadding = useCompact ? 18.0 : 22.0;
    final topGap = useCompact ? 20.0 : 30.0;
    final bottomGap = useCompact ? 18.0 : 28.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(horizontalPadding, useCompact ? 20 : 26, horizontalPadding, useCompact ? 18 : 24),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTopBlock(
            icon: icon,
            iconBackground: iconBackground,
            title: title,
            subtitle: subtitle,
            description: description,
            compact: useCompact,
          ),
          SizedBox(height: topGap),
          _BenefitsGrid(items: benefits, compact: useCompact),
          SizedBox(height: bottomGap),
          _GradientActionButton(
            label: buttonLabel,
            gradient: buttonGradient,
            onTap: onTap,
            compact: useCompact,
          ),
        ],
      ),
    );
  }
}

class _CardTopBlock extends StatelessWidget {
  final Widget icon;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final String description;
  final bool compact;

  const _CardTopBlock({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 370;
    final useCompact = isCompact || compact;
    final titleSize = useCompact ? 30.0 : 37.0;
    final subtitleSize = useCompact ? 18.0 : 21.0;
    final descriptionSize = useCompact ? 14.0 : 17.0;
    final titleGap = useCompact ? 8.0 : 12.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Center(child: icon),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                    letterSpacing: -1.2,
                    color: kTextDark,
                  ),
                ),
                SizedBox(height: titleGap),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: subtitleSize,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    color: kBlueText,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: titleGap),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: descriptionSize,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: kTextGrey,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BenefitsGrid extends StatelessWidget {
  final List<String> items;
  final bool compact;

  const _BenefitsGrid({required this.items, required this.compact});

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4);

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _BenefitItem(text: items[0], compact: compact)),
            const SizedBox(width: 16),
            Expanded(child: _BenefitItem(text: items[1], compact: compact)),
          ],
        ),
        SizedBox(height: compact ? 14 : 22),
        Row(
          children: [
            Expanded(child: _BenefitItem(text: items[2], compact: compact)),
            const SizedBox(width: 16),
            Expanded(child: _BenefitItem(text: items[3], compact: compact)),
          ],
        ),
      ],
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final String text;
  final bool compact;

  const _BenefitItem({required this.text, required this.compact});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 370;
    final fontSize = (isCompact || compact) ? 14.0 : 17.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.only(top: 1),
          decoration: const BoxDecoration(
            color: kGreenCheck,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 19,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1.18,
              color: const Color(0xFF0A0A0A),
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  final String label;
  final Gradient gradient;
  final ValueChanged<BuildContext>? onTap;
  final bool compact;

  const _GradientActionButton({
    required this.label,
    required this.gradient,
    this.onTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(31),
      child: InkWell(
        borderRadius: BorderRadius.circular(31),
        onTap: onTap != null ? () => onTap!(context) : null,
        child: Ink(
          height: compact ? 54 : 62,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(31),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 19 : 23,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: -0.25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
