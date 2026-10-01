import 'package:flutter/material.dart';

import '../../../../app_core.dart';

class PublishOfferFlowHint extends StatelessWidget {
  const PublishOfferFlowHint({
    super.key,
    required this.message,
    required this.completed,
    required this.analyzing,
  });

  final String message;
  final bool completed;
  final bool analyzing;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: completed ? const Color(0xFFF2F8FF) : const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed ? const Color(0xFFD7E7FF) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            analyzing
                ? Icons.auto_awesome_rounded
                : completed
                    ? Icons.check_circle_outline_rounded
                    : Icons.tips_and_updates_outlined,
            color: completed ? kPrestoBlue : const Color(0xFF5B6475),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: completed ? FontWeight.w700 : FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PublishOfferManualEntry extends StatelessWidget {
  const PublishOfferManualEntry({
    super.key,
    required this.active,
    required this.busy,
    required this.onSelected,
  });

  final bool active;
  final bool busy;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    if (active) {
      return const Text(
        'Saisie manuelle activée · Aide IA facultative',
        textAlign: TextAlign.center,
        style: TextStyle(color: kPrestoBlue, fontWeight: FontWeight.w600),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const ValueKey('publish-manual-entry'),
        onPressed: busy ? null : onSelected,
        icon: const Icon(Icons.edit_note_outlined),
        label: const Text('Remplir sans l’IA'),
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrestoBlue,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
