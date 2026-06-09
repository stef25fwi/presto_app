import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/business_project_sheet.dart';
import '../services/business_guidance_service.dart';

class BusinessProjectSheetPage extends StatelessWidget {
  const BusinessProjectSheetPage({super.key});

  static const routeName = '/business-project-sheet';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: _NotConnectedState(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes fiches projet'),
      ),
      body: StreamBuilder<List<BusinessProjectSheet>>(
        stream: BusinessGuidanceService().watchUserProjectSheets(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: 'Impossible de charger les fiches projet.',
              details: snapshot.error.toString(),
            );
          }

          final sheets = snapshot.data ?? const <BusinessProjectSheet>[];

          if (sheets.isEmpty) {
            return const _EmptySheetsState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sheets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final sheet = sheets[index];
              return _ProjectSheetCard(sheet: sheet);
            },
          );
        },
      ),
    );
  }
}

class _ProjectSheetCard extends StatelessWidget {
  const _ProjectSheetCard({required this.sheet});

  final BusinessProjectSheet sheet;

  @override
  Widget build(BuildContext context) {
    final location = <String>[
      if (sheet.city.trim().isNotEmpty) sheet.city,
      if (sheet.department.trim().isNotEmpty) sheet.department,
      sheet.regionCode,
    ].join(' • ');

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.description_outlined),
        title: Text(
          sheet.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(location),
        children: [
          _InfoRow(
            label: 'Type de projet',
            value: sheet.projectType,
          ),
          _InfoRow(
            label: 'Statut',
            value: sheet.status,
          ),
          if (sheet.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionTitle('Résumé'),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(sheet.summary),
            ),
          ],
          const SizedBox(height: 12),
          _TextListBlock(
            title: 'Étapes',
            items: sheet.steps,
            emptyText: 'Aucune étape enregistrée.',
          ),
          const SizedBox(height: 12),
          _TextListBlock(
            title: 'Checklist',
            items: sheet.checklist,
            emptyText: 'Aucune checklist enregistrée.',
          ),
          const SizedBox(height: 12),
          _TextListBlock(
            title: 'Organismes liés',
            items: sheet.organizationIds,
            emptyText: 'Aucun organisme lié pour le moment.',
          ),
          const SizedBox(height: 12),
          _TextListBlock(
            title: 'Aides publiques liées',
            items: sheet.publicAidIds,
            emptyText: 'Aucune aide publique liée pour le moment.',
          ),
          const SizedBox(height: 12),
          _BudgetBlock(sheet: sheet),
        ],
      ),
    );
  }
}

class _BudgetBlock extends StatelessWidget {
  const _BudgetBlock({required this.sheet});

  final BusinessProjectSheet sheet;

  @override
  Widget build(BuildContext context) {
    if (!sheet.hasBudget) {
      return const _InfoRow(
        label: 'Budget',
        value: 'Non renseigné',
      );
    }

    return _InfoRow(
      label: 'Budget estimatif',
      value: '${sheet.estimatedBudgetMin} € à ${sheet.estimatedBudgetMax} €',
    );
  }
}

class _TextListBlock extends StatelessWidget {
  const _TextListBlock({
    required this.title,
    required this.items,
    required this.emptyText,
  });

  final String title;
  final List<String> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Text(emptyText)
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label : ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
    );
  }
}

class _EmptySheetsState extends StatelessWidget {
  const _EmptySheetsState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.description_outlined, size: 52),
        const SizedBox(height: 16),
        Text(
          'Aucune fiche projet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Va dans “Créer mon activité”, choisis un projet puis clique sur “Générer ma fiche projet”.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _NotConnectedState extends StatelessWidget {
  const _NotConnectedState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes fiches projet'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Connecte-toi pour afficher tes fiches projet.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.details,
  });

  final String message;
  final String details;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.error_outline, size: 52),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          details,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
