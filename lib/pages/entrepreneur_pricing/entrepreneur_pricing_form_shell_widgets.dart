import 'package:flutter/material.dart';

import '../../constants.dart';

const formOrange = Color(0xFFFF6600);
const formBlue = Color(0xFF1A73E8);
const formExpertBlue = Color(0xFF0F4C81);

class PricingHeader extends StatelessWidget implements PreferredSizeWidget {
  const PricingHeader({
    super.key,
    required this.color,
    required this.onBack,
    this.homeBack = false,
  });

  final Color color;
  final VoidCallback onBack;
  final bool homeBack;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: color,
      foregroundColor: Colors.white,
      leading: IconButton(
        key: const ValueKey('pricing-header-back'),
        tooltip: homeBack ? 'Retour à l’accueil' : 'Retour',
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

class PricingSection extends StatelessWidget {
  const PricingSection({
    super.key,
    required this.number,
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
    this.subtitle,
  });

  final int number;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      spaced.add(children[index]);
      if (index < children.length - 1) spaced.add(const SizedBox(height: 10));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color,
                    child: Icon(icon, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$number. $title',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(children: spaced),
            ),
          ],
        ),
      ),
    );
  }
}

class PricingPrimaryButton extends StatelessWidget {
  const PricingPrimaryButton({
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
      height: 56,
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
        label: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}