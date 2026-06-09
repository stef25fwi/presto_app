import 'package:flutter/material.dart';

class BusinessProjectSheetPage extends StatelessWidget {
  const BusinessProjectSheetPage({super.key});

  static const routeName = '/business-project-sheet';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma fiche projet'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ProjectSection(
            title: 'Résumé du projet',
            items: [
              'Type de projet',
              'Région',
              'Département',
              'Ville',
              'Objectif principal',
            ],
          ),
          SizedBox(height: 12),
          _ProjectSection(
            title: 'Étapes administratives',
            items: [
              'Définir le projet',
              'Choisir le statut juridique',
              'Vérifier les autorisations',
              'Préparer les documents',
              'Contacter les organismes locaux',
            ],
          ),
          SizedBox(height: 12),
          _ProjectSection(
            title: 'Organismes utiles',
            items: [
              'CCI',
              'CMA si activité artisanale',
              'Région',
              'France Travail',
              'France Services',
            ],
          ),
          SizedBox(height: 12),
          _ProjectSection(
            title: 'Checklist',
            items: [
              'Pièce d’identité',
              'Justificatif de domicile',
              'Description du projet',
              'Budget estimatif',
              'Assurance professionnelle à vérifier',
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectSection extends StatelessWidget {
  const _ProjectSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            for (final item in items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(item),
              ),
          ],
        ),
      ),
    );
  }
}
