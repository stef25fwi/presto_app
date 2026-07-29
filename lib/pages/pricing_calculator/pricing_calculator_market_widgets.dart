part of '../pricing_calculator_page.dart';

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label :',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _MarketCard extends StatelessWidget {
  final double marketLow;
  final double marketMid;
  final double marketHigh;
  final double price;
  final String label;
  final String hint;
  final Color levelColor;

  const _MarketCard({
    required this.marketLow,
    required this.marketMid,
    required this.marketHigh,
    required this.price,
    required this.label,
    required this.hint,
    required this.levelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Positionnement Marché',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Prix du marché : ${_money(marketLow)} € - ${_money(marketMid)} € - ${_money(marketHigh)} €',
            style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Ton prix conseillé : ${_money(price)} €',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: levelColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: levelColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: levelColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hint,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _MarketMiniCard extends StatelessWidget {
  final TextEditingController lowCtrl;
  final TextEditingController midCtrl;
  final TextEditingController highCtrl;
  final VoidCallback onChanged;

  const _MarketMiniCard({
    required this.lowCtrl,
    required this.midCtrl,
    required this.highCtrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Marché (optionnel)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _MiniMarketField(
                      label: 'Bas', ctrl: lowCtrl, onChanged: onChanged)),
              const SizedBox(width: 10),
              Expanded(
                  child: _MiniMarketField(
                      label: 'Moyen', ctrl: midCtrl, onChanged: onChanged)),
              const SizedBox(width: 10),
              Expanded(
                  child: _MiniMarketField(
                      label: 'Haut', ctrl: highCtrl, onChanged: onChanged)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMarketField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final VoidCallback onChanged;

  const _MiniMarketField({
    required this.label,
    required this.ctrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      textAlign: TextAlign.center,
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
        labelText: label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

