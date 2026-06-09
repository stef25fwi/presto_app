import 'package:flutter/material.dart';

class ProfessionalProfilePage extends StatelessWidget {
  const ProfessionalProfilePage({super.key});

  static const routeName = '/professional-profile';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma fiche Pro'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _InfoCard(
            title: 'Identité professionnelle',
            text:
                'Nom commercial, description longue, ville, région, catégories de services et années d’expérience.',
            icon: Icons.business_center_outlined,
          ),
          SizedBox(height: 12),
          _InfoCard(
            title: 'SIRET et confiance',
            text:
                'Affichage du SIRET, du statut de vérification et des badges de confiance.',
            icon: Icons.verified_user_outlined,
          ),
          SizedBox(height: 12),
          _InfoCard(
            title: 'Réalisations',
            text:
                'Photos de travaux, exemples de prestations, zone d’intervention et disponibilités.',
            icon: Icons.photo_library_outlined,
          ),
          SizedBox(height: 12),
          _InfoCard(
            title: 'Avis et notation',
            text:
                'Note moyenne, nombre d’avis, score de confiance et retours clients.',
            icon: Icons.star_border,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.text,
    required this.icon,
  });

  final String title;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
