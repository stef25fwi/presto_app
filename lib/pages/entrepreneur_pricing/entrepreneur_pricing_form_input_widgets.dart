import 'package:flutter/material.dart';

class PricingNumberField extends StatelessWidget {
  const PricingNumberField({
    super.key,
    required this.label,
    required this.controller,
    required this.suffix,
    required this.onChanged,
    this.integer = false,
  });

  final String label;
  final TextEditingController controller;
  final String suffix;
  final ValueChanged<String> onChanged;
  final bool integer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 125,
          child: TextField(
            controller: controller,
            keyboardType: integer
                ? TextInputType.number
                : const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              suffixText: suffix,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PricingInfoPill extends StatelessWidget {
  const PricingInfoPill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

InputDecoration pricingTextDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: const Color(0xFFF3F4F6),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}