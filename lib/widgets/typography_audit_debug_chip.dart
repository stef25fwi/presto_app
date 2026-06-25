import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../debug_tools/typography_audit_service.dart';

class TypographyAuditDebugChip extends StatelessWidget {
  const TypographyAuditDebugChip({super.key});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      visualDensity: VisualDensity.compact,
      avatar: const Icon(Icons.text_fields_rounded, size: 15),
      label: const Text(
        'Audit typo',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      onPressed: () => _copyAndShowAudit(context),
    );
  }

  static Future<void> _copyAndShowAudit(BuildContext context) async {
    final json = TypographyAuditService.buildPrettyJson(context);

    await Clipboard.setData(ClipboardData(text: json));

    debugPrint('================ TYPOGRAPHY AUDIT START ================');
    debugPrint(json);
    debugPrint('================ TYPOGRAPHY AUDIT END ==================');

    developer.log(
      json,
      name: 'ILIPRESTO_TYPOGRAPHY_AUDIT',
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Audit typographique copié dans le presse-papiers.'),
        duration: Duration(seconds: 3),
      ),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Audit typographique'),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: SingleChildScrollView(
              child: SelectableText(
                json,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: json));

                if (!dialogContext.mounted) return;

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('JSON audit typo copié.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copier le texte'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }
}
