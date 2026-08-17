import 'package:flutter/material.dart';

import 'verification_status_tooltip.dart';

class ProSiretResultBox extends StatelessWidget {
  const ProSiretResultBox({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tooltipMessage,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? tooltipMessage;

  @override
  Widget build(BuildContext context) {
    final tooltip = tooltipMessage;
    final titleWidget = Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tooltip == null)
                  titleWidget
                else
                  VerificationStatusTooltip(
                    message: tooltip,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: titleWidget),
                        const SizedBox(width: 6),
                        const Icon(Icons.info_outline_rounded, size: 17),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
