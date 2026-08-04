import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:presto_app/pages/toolbox_hub_page.dart';
import '../app/presto_design_tokens.dart';

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
    final width = MediaQuery.sizeOf(context).width;
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
          // Le blanc sur l'orange de marque plafonne à 2,94:1 : le design
          // system impose le texte principal sur toute surface orange.
          foregroundColor: PrestoColors.textOnOrange,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: kToolboxAppBarColor,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          title: const Text(
            'Boîte à outils',
            // Le style de titre du thème global est blanc : sur une barre
            // orange, il doit être redéfini explicitement.
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: PrestoColors.textOnOrange,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isShort = constraints.maxHeight < 760;
              final isVeryShort = constraints.maxHeight < 710;
              final isUltraShort = constraints.maxHeight < 650;
              final horizontalPadding = width < 370 ? 4.0 : 6.0;
              final verticalPadding = isUltraShort ? 6.0 : 8.0;
              final cardSpacing =
                  isUltraShort ? 8.0 : (isVeryShort ? 10.0 : 12.0);
              final cardHeight =
                  (constraints.maxHeight -
                      (verticalPadding * 2) -
                      cardSpacing) /
                  2;
              // DETTE CONNUE — les deux cartes se partagent l'écran à hauteur
              // figée et `_ToolboxCard` distribue cette hauteur avec des
              // `Expanded`. La page déborde donc sur un écran plus haut que
              // celui pour lequel elle a été réglée (191 px) et à texte
              // agrandi (1 276 px à 200 %). La corriger suppose de rendre la
              // carte intrinsèque, c'est-à-dire de remplacer sa distribution
              // verticale : voir quality/flutter_architecture_size_budget.json.
              Widget sized(Widget card) =>
                  SizedBox(height: cardHeight, child: card);

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Center(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: shouldConstrain ? 430 : double.infinity,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          sized(
                            _ToolboxCard(
                              icon: Icon(
                                Icons.rocket_launch_rounded,
                                size: isVeryShort ? 30 : 38,
                                color: const Color(0xFFFF5A00),
                              ),
                              iconBackground: kIconOrangeBg,
                              title: 'JE CRÉE MON\nACTIVITÉ',
                              subtitle: 'Un parcours simple pour me lancer.',
                              description:
                                  'Comprends la réglementation, les démarches et les aides utiles selon ta région, ton statut et ton activité.',
                              benefits: const [
                                'Statut juridique\nconseillé',
                                'Coûts & démarches\nexactes',
                                'Aides, subventions &\norganismes',
                                'Plan d’action sur 30\njours',
                              ],
                            buttonLabel: 'Commencer mon parcours',
                            buttonGradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [kBlueStart, kBlueEnd],
                            ),
                            onTap: _openCreateBusiness,
                            compact: isShort,
                            tight: isVeryShort,
                            ultraTight: isUltraShort,
                          ),
                        ),
                        SizedBox(height: cardSpacing),
                        sized(
                          _ToolboxCard(
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
  const _ToolboxCard({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.benefits,
    required this.buttonLabel,
    required this.buttonGradient,
    required this.onTap,
    required this.compact,
    required this.tight,
    required this.ultraTight,
  });

  final Widget icon;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final String description;
  final List<String> benefits;
  final String buttonLabel;
  final Gradient buttonGradient;
  final ValueChanged<BuildContext> onTap;
  final bool compact;
  final bool tight;
  final bool ultraTight;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 370;
    final useCompact = isNarrow || compact || tight || ultraTight;
    final horizontalPadding =
        ultraTight ? 12.0 : (tight ? 14.0 : (useCompact ? 16.0 : 20.0));
    final verticalPadding =
        ultraTight ? 10.0 : (tight ? 12.0 : (useCompact ? 14.0 : 18.0));
    final topGap =
        ultraTight ? 6.0 : (tight ? 8.0 : (useCompact ? 12.0 : 18.0));
    final buttonGap =
        ultraTight ? 6.0 : (tight ? 8.0 : (useCompact ? 10.0 : 14.0));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        verticalPadding,
        horizontalPadding,
        verticalPadding,
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
        mainAxisSize: MainAxisSize.max,
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
          const Spacer(),
          SizedBox(height: buttonGap),
          _GradientActionButton(
            label: buttonLabel,
            gradient: buttonGradient,
            onTap: onTap,
            compact: useCompact,
            tight: tight,
            ultraTight: ultraTight,
          ),
        ],
      ),
    );
  }
}

class _CardTopBlock extends StatelessWidget {
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

  final Widget icon;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final String description;
  final bool compact;
  final bool tight;
  final bool ultraTight;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useCompact = width < 370 || compact || tight || ultraTight;
    final titleSize =
        ultraTight ? 18.0 : (tight ? 22.0 : (useCompact ? 26.0 : 32.0));
    final subtitleSize =
        ultraTight ? 11.0 : (tight ? 13.0 : (useCompact ? 15.0 : 18.0));
    final descriptionSize =
        ultraTight ? 10.0 : (tight ? 11.5 : (useCompact ? 12.5 : 15.0));
    final titleGap =
        ultraTight ? 3.0 : (tight ? 4.0 : (useCompact ? 6.0 : 10.0));
    final iconSize =
        ultraTight ? 48.0 : (tight ? 56.0 : (useCompact ? 62.0 : 72.0));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Center(child: icon),
        ),
        SizedBox(
          width: ultraTight ? 8 : (tight ? 10 : (useCompact ? 12 : 16)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Rubik',
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
  const _BenefitsGrid({
    required this.items,
    required this.compact,
    required this.tight,
    required this.ultraTight,
  });

  final List<String> items;
  final bool compact;
  final bool tight;
  final bool ultraTight;

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4);
    final horizontalGap = ultraTight ? 8.0 : (tight ? 10.0 : 16.0);
    final verticalGap =
        ultraTight ? 6.0 : (tight ? 8.0 : (compact ? 10.0 : 16.0));

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
            SizedBox(width: horizontalGap),
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
        SizedBox(height: verticalGap),
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
            SizedBox(width: horizontalGap),
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
  const _BenefitItem({
    required this.text,
    required this.compact,
    required this.tight,
    required this.ultraTight,
  });

  final String text;
  final bool compact;
  final bool tight;
  final bool ultraTight;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 370;
    final fontSize = ultraTight
        ? 9.8
        : (tight ? 11.5 : ((isNarrow || compact) ? 12.5 : 15.0));
    final checkSize =
        ultraTight ? 18.0 : (tight ? 20.0 : (compact ? 22.0 : 24.0));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: checkSize,
          height: checkSize,
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
  const _GradientActionButton({
    required this.label,
    required this.gradient,
    required this.onTap,
    required this.compact,
    required this.tight,
    required this.ultraTight,
  });

  final String label;
  final Gradient gradient;
  final ValueChanged<BuildContext> onTap;
  final bool compact;
  final bool tight;
  final bool ultraTight;

  @override
  Widget build(BuildContext context) {
    final buttonHeight =
        ultraTight ? 48.0 : (tight ? 52.0 : (compact ? 58.0 : 62.0));
    final fontSize =
        ultraTight ? 14.0 : (tight ? 16.0 : (compact ? 18.0 : 21.0));

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(31),
      child: InkWell(
        borderRadius: BorderRadius.circular(31),
        onTap: () => onTap(context),
        child: Ink(
          height: buttonHeight,
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
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
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
