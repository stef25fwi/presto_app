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
const double kToolboxOuterPadding = 8;
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: kToolboxAppBarColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
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
                    final isVeryShort = constraints.maxHeight < 710;
                    final isUltraShort = constraints.maxHeight < 650;
                    final cardSpacing = isUltraShort ? 10.0 : (isVeryShort ? 12.0 : 16.0);

                    Widget buildCards({double? forcedHeight}) {
                      final card1 = _ToolboxCard(
                        icon: Icon(
                          Icons.rocket_launch_rounded,
                          size: isVeryShort ? 30 : 38,
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
                        secondaryButtonLabel: 'Je me lance',
                        secondaryButtonColor: const Color(0xFF1A73E8),
                        secondaryOnTap: _openMyParcours,
                        onTap: _openCreateBusiness,
                        compact: isShort,
                        tight: isVeryShort,
                        ultraTight: isUltraShort,
                      );

                      final card2 = _ToolboxCard(
                        icon: Icon(
                          Icons.calculate_rounded,
                          size: isVeryShort ? 32 : 40,
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
                        ultraTight: isUltraShort,
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
                        10,
                        kToolboxOuterPadding,
                        10,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: shouldConstrain ? 430 : double.infinity,
                          ),
                          child: buildCards(
                            forcedHeight:
                                (constraints.maxHeight - 20 - cardSpacing) / 2,
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
      ),
    );
  }
}

void _openCreateBusiness(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const CurrentToolboxPage()),
  );
}

void _openMyParcours(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const CurrentToolboxSummaryPage()),
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
  final bool ultraTight;
  final String? secondaryButtonLabel;
  final Color? secondaryButtonColor;
  final ValueChanged<BuildContext>? secondaryOnTap;

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
    this.ultraTight = false,
    this.secondaryButtonLabel,
    this.secondaryButtonColor,
    this.secondaryOnTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 370;
    final useCompact = isCompact || compact || tight || ultraTight;
    final horizontalPadding = ultraTight
      ? 12.0
      : (tight ? 14.0 : (useCompact ? 16.0 : 20.0));
    final topGap = ultraTight ? 8.0 : (tight ? 10.0 : (useCompact ? 16.0 : 24.0));
    final bottomGap = ultraTight ? 8.0 : (tight ? 10.0 : (useCompact ? 14.0 : 22.0));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        ultraTight ? 12 : (tight ? 14 : (useCompact ? 18 : 22)),
        horizontalPadding,
        ultraTight ? 10 : (tight ? 12 : (useCompact ? 14 : 18)),
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
            ultraTight: ultraTight,
          ),
          SizedBox(height: topGap),
          _BenefitsGrid(
            items: benefits,
            compact: useCompact,
            tight: tight,
            ultraTight: ultraTight,
          ),
          SizedBox(height: bottomGap),
          _GradientActionButton(
            label: buttonLabel,
            gradient: buttonGradient,
            onTap: onTap,
            compact: useCompact,
            tight: tight,
            ultraTight: ultraTight,
          ),
          if (secondaryButtonLabel != null && secondaryOnTap != null) ...[
            SizedBox(height: ultraTight ? 6 : (tight ? 8 : 10)),
            _SolidActionButton(
              label: secondaryButtonLabel!,
              color: secondaryButtonColor ?? const Color(0xFF1A73E8),
              onTap: secondaryOnTap!,
              compact: useCompact,
              tight: tight,
              ultraTight: ultraTight,
            ),
          ],
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
  final bool ultraTight;

  const _CardTopBlock({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.compact,
    required this.tight,
    required this.ultraTight,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 370;
    final useCompact = isCompact || compact || tight || ultraTight;
    final titleSize = ultraTight ? 18.0 : (tight ? 22.0 : (useCompact ? 26.0 : 32.0));
    final subtitleSize = ultraTight ? 11.0 : (tight ? 13.0 : (useCompact ? 15.0 : 18.0));
    final descriptionSize = ultraTight ? 10.0 : (tight ? 11.5 : (useCompact ? 12.5 : 15.0));
    final titleGap = ultraTight ? 3.0 : (tight ? 4.0 : (useCompact ? 6.0 : 10.0));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: ultraTight ? 48 : (tight ? 56 : (useCompact ? 62 : 72)),
          height: ultraTight ? 48 : (tight ? 56 : (useCompact ? 62 : 72)),
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Center(child: icon),
        ),
        SizedBox(width: ultraTight ? 8 : (tight ? 10 : (useCompact ? 12 : 16))),
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
  final bool ultraTight;

  const _BenefitsGrid({
    required this.items,
    required this.compact,
    required this.tight,
    required this.ultraTight,
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
                ultraTight: ultraTight,
              ),
            ),
            SizedBox(width: ultraTight ? 8 : (tight ? 10 : 16)),
            Expanded(
              child: _BenefitItem(
                text: items[1],
                compact: compact,
                tight: tight,
                ultraTight: ultraTight,
              ),
            ),
          ],
        ),
        SizedBox(height: ultraTight ? 8 : (tight ? 10 : (compact ? 14 : 22))),
        Row(
          children: [
            Expanded(
              child: _BenefitItem(
                text: items[2],
                compact: compact,
                tight: tight,
                ultraTight: ultraTight,
              ),
            ),
            SizedBox(width: ultraTight ? 8 : (tight ? 10 : 16)),
            Expanded(
              child: _BenefitItem(
                text: items[3],
                compact: compact,
                tight: tight,
                ultraTight: ultraTight,
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
  final bool ultraTight;

  const _BenefitItem({
    required this.text,
    required this.compact,
    required this.tight,
    required this.ultraTight,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 370;
    final fontSize = ultraTight
      ? 9.8
      : (tight ? 11.5 : ((isCompact || compact) ? 12.5 : 15.0));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: ultraTight ? 18 : (tight ? 20 : (compact ? 22 : 24)),
          height: ultraTight ? 18 : (tight ? 20 : (compact ? 22 : 24)),
          margin: const EdgeInsets.only(top: 1),
          decoration: const BoxDecoration(
            color: kGreenCheck,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: ultraTight ? 13 : (tight ? 15 : 16),
            color: Colors.white,
          ),
        ),
        SizedBox(width: ultraTight ? 6 : (tight ? 8 : 11)),
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
  final bool ultraTight;

  const _GradientActionButton({
    required this.label,
    required this.gradient,
    this.onTap,
    required this.compact,
    required this.tight,
    required this.ultraTight,
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
          height: ultraTight ? 36 : (tight ? 44 : (compact ? 50 : 56)),
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
                  fontSize: ultraTight ? 12.5 : (tight ? 15 : (compact ? 17 : 20)),
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

class _SolidActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final ValueChanged<BuildContext> onTap;
  final bool compact;
  final bool tight;
  final bool ultraTight;

  const _SolidActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    required this.compact,
    required this.tight,
    required this.ultraTight,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => onTap(context),
        child: Ink(
          height: ultraTight ? 34 : (tight ? 40 : (compact ? 44 : 48)),
          width: double.infinity,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: ultraTight ? 12 : (tight ? 14 : (compact ? 15 : 17)),
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
