import 'package:flutter/material.dart';

import 'pro_declared_leader_fields.dart';

class DeclaredLeaderIdentity {
  const DeclaredLeaderIdentity({
    required this.firstName,
    required this.lastName,
  });

  final String firstName;
  final String lastName;
}

Future<DeclaredLeaderIdentity?> showProDeclaredLeaderDialog(
  BuildContext context,
) async {
  final formKey = GlobalKey<FormState>();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();

  try {
    return await showDialog<DeclaredLeaderIdentity>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dirigeant déclaré'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: ProDeclaredLeaderFields(
              firstNameController: firstNameController,
              lastNameController: lastNameController,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(dialogContext).pop(
                DeclaredLeaderIdentity(
                  firstName: firstNameController.text.trim(),
                  lastName: lastNameController.text.trim(),
                ),
              );
            },
            child: const Text('Continuer la vérification'),
          ),
        ],
      ),
    );
  } finally {
    firstNameController.dispose();
    lastNameController.dispose();
  }
}
