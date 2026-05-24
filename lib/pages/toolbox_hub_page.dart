import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:presto_app/pages/pricing_calculator_page.dart';
import 'package:presto_app/pages/toolbox_je_me_lance_page.dart';

class AppRoutes {
  static const toolboxHub = '/toolbox_hub';
  static const toolboxCurrent = '/toolbox_current';
  static const entrepreneurCalculator = '/entrepreneur_calculator';
}

class ToolboxHubPage extends StatelessWidget {
  const ToolboxHubPage({super.key});

  static const Color _orange = Color(0xFFFF5A00);
  static const Color _orangeDark = Color(0xFFFF2F00);
  static const Color _blue = Color(0xFF0A7DFF);
  static const Color _blueDark = Color(0xFF0034C8);
  static const Color _pageBg = Color(0xFFF4F5F7);
  static const Color _titleColor = Color(0xFF090D1A);
  static const Color _textColor = Color(0xFF4E5360);
  static const Color _success = Color(0xFF2EAA6F);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _orange,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Boîte à outils'),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 760;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  compact ? 10 : 14,
                  16,
                  compact ? 12 : 18,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: _ToolboxCard(
                        compact: compact,
                        icon: Icons.rocket_launch_rounded,
                        iconColor: _orange,
                        iconBackground: const Color(0xFFFFEEE5),
                        titleLines: const [
                          'CRÉER MON',
                          'ENTREPRISE',
                        ],
                        subtitle: 'Prestō me guide pas à pas.',
                        description:
                            'Décris ton projet, ta situation et ton territoire pour obtenir des conseils concrets.',
                        leftItems: const [
                          'Statut juridique\nconseillé',
                          'Aides, subventions &\norganismes',
                        ],
                        rightItems: const [
                          'Coûts & démarches\nexactes',
                          'Plan d’action sur 30\njours',
                        ],
                        buttonLabel: 'Démarrer mon projet',
                        buttonGradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [_blue, _blueDark],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CurrentToolboxPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 16),
                    Expanded(
                      child: _ToolboxCard(
                        compact: compact,
                        icon: Icons.calculate_rounded,
                        iconColor: const Color(0xFF1565D8),
                        iconBackground: const Color(0xFFEAF3FF),
                        titleLines: const [
                          'FIXER MON PRIX',
                          'DE VENTE',
                        ],
                        subtitle: 'Je calcule un prix rentable.',
                        description:
                            'En quelques clics, j’estime mon coût de revient, mes charges et mon positionnement marché.',
                        leftItems: const [
                          'Matières premières',
                          'Charges & frais réels',
                        ],
                        rightItems: const [
                          'Temps de travail',
                          'Positionnement face à\nla concurrence',
                        ],
                        buttonLabel: 'Calculer mon prix',
                        buttonGradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [_orange, _orangeDark],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const EntrepreneurCalculatorPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ToolboxHeader extends StatelessWidget {
  const _ToolboxHeader({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: topPadding + 86,
      padding: EdgeInsets.only(top: topPadding),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            ToolboxHubPage._orange,
            ToolboxHubPage._orangeDark,
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 8,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolboxCard extends StatelessWidget {
  const _ToolboxCard({
    required this.compact,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.titleLines,
    required this.subtitle,
    required this.description,
    required this.leftItems,
    required this.rightItems,
    required this.buttonLabel,
    required this.buttonGradient,
    required this.onTap,
  });

  final bool compact;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final List<String> titleLines;
  final String subtitle;
  final String description;
  final List<String> leftItems;
  final List<String> rightItems;
  final String buttonLabel;
  final Gradient buttonGradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 20,
        compact ? 16 : 22,
        compact ? 16 : 20,
        compact ? 16 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 24 : 28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconTile(
                compact: compact,
                icon: icon,
                iconColor: iconColor,
                backgroundColor: iconBackground,
              ),
              SizedBox(width: compact ? 14 : 18),
              Expanded(
                child: _CardIntro(
                  compact: compact,
                  titleLines: titleLines,
                  subtitle: subtitle,
                  description: description,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 16 : 28),
          _ChecklistGrid(
            compact: compact,
            leftItems: leftItems,
            rightItems: rightItems,
          ),
          SizedBox(height: compact ? 16 : 28),
          _GradientButton(
            compact: compact,
            label: buttonLabel,
            gradient: buttonGradient,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.compact,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });

  final bool compact;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 56 : 68,
      height: compact ? 56 : 68,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
      ),
      child: Icon(
        icon,
        color: iconColor,
        size: compact ? 30 : 36,
      ),
    );
  }
}

class _CardIntro extends StatelessWidget {
  const _CardIntro({
    required this.compact,
    required this.titleLines,
    required this.subtitle,
    required this.description,
  });

  final bool compact;
  final List<String> titleLines;
  final String subtitle;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StrongTitle(lines: titleLines, compact: compact),
        SizedBox(height: compact ? 4 : 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Color(0xFF1565D8),
            fontSize: compact ? 17 : 20,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        Text(
          description,
          style: TextStyle(
            color: ToolboxHubPage._textColor,
            fontSize: compact ? 14 : 16.5,
            fontWeight: FontWeight.w500,
            height: 1.35,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class _StrongTitle extends StatelessWidget {
  const _StrongTitle({required this.lines, required this.compact});

  final List<String> lines;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                line,
                maxLines: 1,
                style: TextStyle(
                  color: ToolboxHubPage._titleColor,
                  fontSize: compact ? 28 : 38,
                  fontWeight: FontWeight.w900,
                  height: 0.95,
                  letterSpacing: -0.8,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChecklistGrid extends StatelessWidget {
  const _ChecklistGrid({
    required this.compact,
    required this.leftItems,
    required this.rightItems,
  });

  final bool compact;
  final List<String> leftItems;
  final List<String> rightItems;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 420;
    if (isNarrow) {
      final allItems = [...leftItems, ...rightItems];
      return Column(
        children: [
          for (int i = 0; i < allItems.length; i++) ...[
            _CheckItem(text: allItems[i], compact: compact),
            if (i != allItems.length - 1)
              SizedBox(height: compact ? 10 : 18),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              for (int i = 0; i < leftItems.length; i++) ...[
                _CheckItem(text: leftItems[i], compact: compact),
                if (i != leftItems.length - 1)
                  SizedBox(height: compact ? 10 : 18),
              ],
            ],
          ),
        ),
        SizedBox(width: compact ? 12 : 18),
        Expanded(
          child: Column(
            children: [
              for (int i = 0; i < rightItems.length; i++) ...[
                _CheckItem(text: rightItems[i], compact: compact),
                if (i != rightItems.length - 1)
                  SizedBox(height: compact ? 10 : 18),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({required this.text, required this.compact});

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 20 : 25,
          height: compact ? 20 : 25,
          margin: const EdgeInsets.only(top: 1),
          decoration: const BoxDecoration(
            color: ToolboxHubPage._success,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
        SizedBox(width: compact ? 8 : 11),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Color(0xFF17191F),
              fontSize: compact ? 14 : 17.5,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.compact,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  final bool compact;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: SizedBox(
            width: double.infinity,
            height: compact ? 50 : 64,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 17 : 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CurrentToolboxPage extends StatelessWidget {
  const CurrentToolboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ToolboxJeMeLancePage();
  }
}

class EntrepreneurCalculatorPage extends StatelessWidget {
  const EntrepreneurCalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrestoPriceCalculatorApp();
  }
}
