import 'package:flutter/material.dart';

class ProProfileConsentSection extends StatelessWidget {
  const ProProfileConsentSection({
    super.key,
    required this.publicProfileConsent,
    required this.termsAccepted,
    required this.enabled,
    required this.onPublicProfileConsentChanged,
    required this.onTermsAcceptedChanged,
  });

  final bool publicProfileConsent;
  final bool termsAccepted;
  final bool enabled;
  final ValueChanged<bool> onPublicProfileConsentChanged;
  final ValueChanged<bool> onTermsAcceptedChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CheckboxListTile(
          value: publicProfileConsent,
          onChanged: enabled
              ? (value) => onPublicProfileConsentChanged(value ?? false)
              : null,
          title: const Text(
            'Rendre mon profil professionnel visible sur le web',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            'J’accepte que mon profil professionnel soit publié sur ilipresto.fr et puisse être indexé par les moteurs de recherche. Seuls le nom de l’entreprise, l’activité, la description, les catégories, la ville, la zone d’intervention et le site web pourront être publiés. Le SIRET, l’adresse complète, l’e-mail et le téléphone restent privés.',
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: termsAccepted,
          onChanged: enabled
              ? (value) => onTermsAcceptedChanged(value ?? false)
              : null,
          title: const Text(
            "J'accepte les conditions d'utilisation professionnelles",
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
