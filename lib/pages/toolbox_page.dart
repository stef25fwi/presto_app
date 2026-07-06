import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
const Color kToolboxAppBarColor = Color(0xFFFF6600);

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
      appBar: AppBar(
        backgroundColor: kToolboxAppBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text(
          'Boîte à outils',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isShort = constraints.maxHeight < 760;
                  final isVeryShort = constraints.maxHeight < 690;
                  final cardSpacing = isVeryShort ? 14.0 : 18.0;

                  Widget buildCards({double? forcedHeight}) {
                    final card1 = _ToolboxCard(
                      icon: Icon(
                        Icons.rocket_launch_rounded,
                        size: isVeryShort ? 34 : 42,
                        color: const Color(0xFFFF5A00),
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
                      tight: isVeryShort,
                    );

                    final card2 = _ToolboxCard(
                      icon: Icon(
                        Icons.calculate_rounded,
                        size: isVeryShort ? 36 : 44,
                        color: const Color(0xFF096FE8),
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
                      tight: isVeryShort,
                    );

                    if (forcedHeight != null) {
                      return Column(
                        children: [
                          SizedBox(height: forcedHeight, child: card1),
                          SizedBox(height: cardSpacing),
                          SizedBox(height: forcedHeight, child: card2),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        card1,
                        SizedBox(height: cardSpacing),
                        card2,
                      ],
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      kToolboxOuterPadding,
                      16,
                      kToolboxOuterPadding,
                      18,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: shouldConstrain ? 430 : double.infinity,
                        ),
                        child: isVeryShort
                            ? ListView(
                                padding: EdgeInsets.zero,
                                children: [buildCards()],
                              )
                            : buildCards(
                                forcedHeight:
                                    (constraints.maxHeight - 34 - cardSpacing) /
                                        2,
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
  final bool tight;

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
    this.tight = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 370;
    final useCompact = isCompact || compact || tight;
    final horizontalPadding = tight ? 16.0 : (useCompact ? 18.0 : 22.0);
    final topGap = tight ? 14.0 : (useCompact ? 20.0 : 30.0);
    final bottomGap = tight ? 14.0 : (useCompact ? 18.0 : 28.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        tight ? 16 : (useCompact ? 20 : 26),
        horizontalPadding,
        tight ? 14 : (useCompact ? 18 : 24),
      ),
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
            tight: tight,
          ),
          SizedBox(height: topGap),
          _BenefitsGrid(items: benefits, compact: useCompact, tight: tight),
          SizedBox(height: bottomGap),
          _GradientActionButton(
            label: buttonLabel,
            gradient: buttonGradient,
            onTap: onTap,
            compact: useCompact,
            tight: tight,
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
  final bool tight;

  const _CardTopBlock({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.compact,
    required this.tight,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 370;
    final useCompact = isCompact || compact || tight;
    final titleSize = tight ? 25.0 : (useCompact ? 30.0 : 37.0);
    final subtitleSize = tight ? 15.0 : (useCompact ? 18.0 : 21.0);
    final descriptionSize = tight ? 12.5 : (useCompact ? 14.0 : 17.0);
    final titleGap = tight ? 6.0 : (useCompact ? 8.0 : 12.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: tight ? 62 : 74,
          height: tight ? 62 : 74,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Center(child: icon),
        ),
        SizedBox(width: tight ? 12 : 18),
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
  final bool tight;

  const _BenefitsGrid({
    required this.items,
    required this.compact,
    required this.tight,
  });

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _BenefitItem(
                text: items[0],
                compact: compact,
                tight: tight,
              ),
            ),
            SizedBox(width: tight ? 10 : 16),
            Expanded(
              child: _BenefitItem(
                text: items[1],
                compact: compact,
                tight: tight,
              ),
            ),
          ],
        ),
        SizedBox(height: tight ? 10 : (compact ? 14 : 22)),
        Row(
          children: [
            Expanded(
              child: _BenefitItem(
                text: items[2],
                compact: compact,
                tight: tight,
              ),
            ),
            SizedBox(width: tight ? 10 : 16),
            Expanded(
              child: _BenefitItem(
                text: items[3],
                compact: compact,
                tight: tight,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final String text;
  final bool compact;
  final bool tight;

  const _BenefitItem({
    required this.text,
    required this.compact,
    required this.tight,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 370;
    final fontSize = tight ? 12.5 : ((isCompact || compact) ? 14.0 : 17.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: tight ? 22 : 26,
          height: tight ? 22 : 26,
          margin: const EdgeInsets.only(top: 1),
          decoration: const BoxDecoration(
            color: kGreenCheck,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 17,
            color: Colors.white,
          ),
        ),
        SizedBox(width: tight ? 8 : 11),
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
  final bool tight;

  const _GradientActionButton({
    required this.label,
    required this.gradient,
    this.onTap,
    required this.compact,
    required this.tight,
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
          height: tight ? 48 : (compact ? 54 : 62),
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
                  fontSize: tight ? 16 : (compact ? 19 : 23),
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
