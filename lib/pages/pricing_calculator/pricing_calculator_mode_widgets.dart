part of '../pricing_calculator_page.dart';

class _ModeScopeBanner extends StatelessWidget {
  final PricingMode mode;

  const _ModeScopeBanner({required this.mode});

  @override
  Widget build(BuildContext context) {
    final expert = mode == PricingMode.expert;
    final color = expert ? const Color(0xFF0F4C81) : kPrestoBlue;
    final items = expert
        ? const [
            'Tous les calculs Standard',
            'Énergie, eau, transport et territoire',
            'Marché, scénarios, historique et PDF',
          ]
        : const [
            'Coûts directs et temps de travail',
            'Charges fixes et amortissement',
            'Prix minimum, prix conseillé et alerte de perte',
          ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            expert ? 'Ce mode ajoute' : 'Ce mode comprend',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, size: 17, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineHelp extends StatelessWidget {
  final String text;

  const _InlineHelp({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 17, color: Colors.black45),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrestoTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color background;
  final bool showBack;

  const _PrestoTopBar({
    required this.title,
    required this.background,
    required this.showBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: background,
      elevation: 0,
      title: Row(
        children: [
          if (showBack)
            IconButton(
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
            ),
          if (showBack) const SizedBox(width: 2),
          Text(
            title,
            style: kPrestoAppBarTitleStyle.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Color headerColor;
  final IconData headerIcon;
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.headerColor,
    required this.headerIcon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(headerIcon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          )),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.black38),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _RowField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String suffix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  const _RowField({
    required this.icon,
    required this.label,
    required this.controller,
    required this.suffix,
    this.keyboardType,
    this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.black54),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label :',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          width: 110,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType ??
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: onChanged,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixText: suffix,
              suffixStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

class _ToggleTypeRow extends StatelessWidget {
  final bool valueIsPct;
  final ValueChanged<bool> onChanged;

  const _ToggleTypeRow({required this.valueIsPct, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Type :',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 10),
        _PillToggle(
          left: '%',
          right: '€',
          selectedLeft: valueIsPct,
          onChanged: onChanged,
        ),
        const Spacer(),
        const Icon(Icons.info_outline, size: 18, color: Colors.black45),
      ],
    );
  }
}

class _PillToggle extends StatelessWidget {
  final String left;
  final String right;
  final bool selectedLeft;
  final ValueChanged<bool> onChanged;

  const _PillToggle({
    required this.left,
    required this.right,
    required this.selectedLeft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(true),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedLeft ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  left,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: selectedLeft ? Colors.black : Colors.black54,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(false),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedLeft ? Colors.transparent : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  right,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: selectedLeft ? Colors.black54 : Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniInfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickRatePresets extends StatelessWidget {
  final ValueChanged<double> onPick;
  const _QuickRatePresets({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Presets',
      splashRadius: 18,
      icon: const Icon(Icons.tune_rounded, size: 20, color: Colors.black54),
      onSelected: onPick,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 15, child: Text('15 €/h (débutant)')),
        PopupMenuItem(value: 25, child: Text('25 €/h (standard)')),
        PopupMenuItem(value: 35, child: Text('35 €/h (expert)')),
      ],
    );
  }
}
