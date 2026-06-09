import 'package:flutter/material.dart';

class BusinessGuidancePage extends StatelessWidget {
  const BusinessGuidancePage({super.key});

  static const routeName = '/business-guidance';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer mon activité'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _GuidanceHeader(),
          SizedBox(height: 16),
          _GuidanceCard(
            title: 'Parcours personnalisé',
            text:
                'Le parcours s’adapte à la région, au département et à la ville renseignés dans le profil utilisateur.',
            icon: Icons.route_outlined,
          ),
          SizedBox(height: 12),
          _GuidanceCard(
            title: 'Organismes locaux',
            text:
                'CCI, CMA, Région, France Travail, France Services et accompagnateurs locaux.',
            icon: Icons.account_balance_outlined,
          ),
          SizedBox(height: 12),
          _GuidanceCard(
            title: 'Aides publiques',
            text:
                'Affichage des aides publiques disponibles selon la région du profil.',
            icon: Icons.volunteer_activism_outlined,
          ),
          SizedBox(height: 12),
          _GuidanceCard(
            title: 'Fiche projet',
            text:
                'Génération d’une fiche projet avec étapes, checklist, contacts et budget estimatif.',
            icon: Icons.description_outlined,
          ),
        ],
      ),
    );
  }
}

class _GuidanceHeader extends StatelessWidget {
  const _GuidanceHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'De l’idée au lancement',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Aide l’utilisateur à transformer une activité en projet clair, localisé et accompagné.',
        ),
      ],
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({
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
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(text),
      ),
    );
  }
}
