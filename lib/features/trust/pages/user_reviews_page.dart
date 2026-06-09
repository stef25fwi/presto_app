import 'package:flutter/material.dart';

class UserReviewsPage extends StatelessWidget {
  const UserReviewsPage({super.key});

  static const routeName = '/user-reviews';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avis et notation'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _RatingSummaryCard(),
          SizedBox(height: 16),
          _ReviewCriteriaCard(),
          SizedBox(height: 16),
          _EmptyReviewCard(),
        ],
      ),
    );
  }
}

class _RatingSummaryCard extends StatelessWidget {
  const _RatingSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.star_border, size: 42),
            const SizedBox(height: 8),
            Text(
              'Note moyenne',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
                'Les avis apparaîtront ici après les premières missions.'),
          ],
        ),
      ),
    );
  }
}

class _ReviewCriteriaCard extends StatelessWidget {
  const _ReviewCriteriaCard();

  @override
  Widget build(BuildContext context) {
    final criteria = <String>[
      'Communication',
      'Ponctualité',
      'Qualité du travail',
      'Respect du budget',
      'Professionnalisme',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Critères de notation',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            for (final item in criteria)
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

class _EmptyReviewCard extends StatelessWidget {
  const _EmptyReviewCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.rate_review_outlined),
        title: Text('Aucun avis pour le moment'),
        subtitle: Text(
          'Les avis publiés seront affichés dans cette section.',
        ),
      ),
    );
  }
}
