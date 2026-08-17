import 'package:flutter/material.dart';

import '../constants.dart';

/// Bannière d'information de la messagerie (blocage, modération, etc.).
/// Extrait de `pages/messages/conversation_thread_page.dart` pour rester
/// sous le budget de lignes d'un écran ; toujours accessible via l'import
/// de ce fichier grâce à l'`export` qui y est conservé.
class ConversationBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const ConversationBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: kPrestoMetaTextStyle.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
