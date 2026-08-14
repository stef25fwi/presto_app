import 'package:flutter/material.dart';

import 'admin_contact_mail_models.dart';

class AdminContactMailDetailDialog extends StatelessWidget {
  final AdminContactMailItem item;

  const AdminContactMailDetailDialog({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final attachmentCount = item.attachmentCount;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      title: Text(
        item.subject.isEmpty ? '(Sans objet)' : item.subject,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.senderLabel,
                style: const TextStyle(
                  color: Color(0xFF1A73E8),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatAdminContactMailDate(item.receivedAt),
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                ),
              ),
              const Divider(height: 24),
              SelectableText(
                item.body.isEmpty ? item.preview : item.body,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              if (attachmentCount > 0) ...[
                const SizedBox(height: 18),
                Text(
                  '$attachmentCount pièce${attachmentCount > 1 ? 's' : ''} '
                  'jointe${attachmentCount > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
