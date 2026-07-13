import 'package:flutter/material.dart';

class AdminConfirmSensitiveActionDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;

  const AdminConfirmSensitiveActionDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirmer',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD14343),
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
