import 'package:flutter/material.dart';

class AdminMessagingFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final List<String> quickFilters;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onQuickFilterTap;

  const AdminMessagingFilterBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.quickFilters = const <String>[],
    this.onSubmitted,
    this.onQuickFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
          onSubmitted: onSubmitted,
        ),
        if (quickFilters.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickFilters
                .map(
                  (filter) => ActionChip(
                    label: Text(filter),
                    onPressed: onQuickFilterTap == null
                        ? null
                        : () => onQuickFilterTap!(filter),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}
