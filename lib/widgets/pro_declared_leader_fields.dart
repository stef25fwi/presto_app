import 'package:flutter/material.dart';

class ProDeclaredLeaderFields extends StatelessWidget {
  const ProDeclaredLeaderFields({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final bool enabled;
  final VoidCallback? onChanged;

  String? _validateName(String? value, String label) {
    final text = (value ?? '').trim();
    if (text.length < 2) return '$label obligatoire.';
    if (text.length > 100) return '$label trop long.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dirigeant déclaré',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Indiquez le nom et le prénom du dirigeant ou représentant légal déclaré. Ils seront comparés aux données administratives disponibles pour ce SIRET.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6B7280),
                height: 1.35,
              ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: firstNameController,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.givenName],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Prénom du dirigeant *',
            prefixIcon: Icon(Icons.person_outline_rounded),
            border: OutlineInputBorder(),
          ),
          validator: (value) => _validateName(value, 'Prénom'),
          onChanged: (_) => onChanged?.call(),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: lastNameController,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.familyName],
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Nom du dirigeant *',
            prefixIcon: Icon(Icons.badge_outlined),
            border: OutlineInputBorder(),
          ),
          validator: (value) => _validateName(value, 'Nom'),
          onChanged: (_) => onChanged?.call(),
        ),
      ],
    );
  }
}
