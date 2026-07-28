import 'package:flutter/material.dart';

import '../../constants.dart';
import 'entrepreneur_pricing_models.dart';

const pricingOrange = Color(0xFFFF6600);
const pricingBlue = Color(0xFF1A73E8);
const pricingExpertBlue = Color(0xFF0F4C81);

class PricingDecisionCard extends StatelessWidget {
  const PricingDecisionCard({super.key, required this.calculation});

  final EntrepreneurPricingCalculation calculation;

  @override
  Widget build(BuildContext context) {
    final profitable = calculation.expectedPriceIsProfitable;
    final color = profitable ? const Color(0xFF15803D) : const Color(0xFFC62828);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            profitable ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: color,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              profitable
                  ? 'Ton prix envisagé est rentable\n'
                      'Résultat : ${pricingMoney(calculation.expectedUnitProfit)} € / unité'
                  : 'À ce prix, tu perds de l’argent\n'
                      'Résultat : ${pricingMoney(calculation.expectedUnitProfit)} € / unité',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class PricingPanel extends StatelessWidget {
  const PricingPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: pricingBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          ...children,
        ],
      ),
    );
  }
}

class PricingResultRow extends StatelessWidget {
  const PricingResultRow(
    this.label,
    this.value, {
    super.key,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: emphasized ? pricingBlue : Colors.black87,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class PricingActionButton extends StatelessWidget {
  const PricingActionButton({
    super.key,
    required this.text,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class PricingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PricingAppBar({
    super.key,
    required this.color,
    required this.onBack,
  });

  final Color color;
  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: color,
      foregroundColor: Colors.white,
      leading: IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      title: Text(
        'iliprestō',
        style: kPrestoAppBarTitleStyle.copyWith(color: Colors.white),
      ),
    );
  }
}

String pricingMoney(double value) => pricingNumber(value, 2);

String pricingNumber(double value, int digits) =>
    (value.isFinite ? value : 0.0)
        .toStringAsFixed(digits)
        .replaceAll('.', ',');

String pricingDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}