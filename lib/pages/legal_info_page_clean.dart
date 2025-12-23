import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Page d'informations légales — iliprestō (version propre)
class LegalInfoPageClean extends StatelessWidget {
  const LegalInfoPageClean({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.orange,
          title: const Text(
            'iliprestō',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Mentions légales'),
              Tab(text: 'Confidentialité'),
              Tab(text: 'CGU'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: const TabBarView(
          children: [
            _MentionsLegalesView(),
            _ConfidentialiteView(),
            _CGUView(),
          ],
        ),
      ),
    );
  }
}

class _MentionsLegalesView extends StatelessWidget {
  const _MentionsLegalesView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Qui sommes-nous ?',
            style: theme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'iliprestō est une plateforme locale facilitant la mise en relation, '
            'la découverte et le partage d’informations utiles. Notre objectif : '
            'proposer une expérience simple et transparente.',
          ),
          const SizedBox(height: 24),
          Text(
            'Éditeur',
            style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Édité par iliprestō. Adresse et informations disponibles sur demande.',
          ),
          const SizedBox(height: 24),
          Text(
            'Hébergement',
            style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFECECEC))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notre hébergeur garantit sécurité et disponibilité.'),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => _launchUrl(
                        Uri.parse('https://ilipreto.fr/mentions-legales.pdf'),
                      ),
                      child: const Text(
                        'Télécharger nos mentions légales (PDF)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Contact',
            style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Center(
            child: InkWell(
              onTap: () => _launchUrl(Uri.parse('mailto:contact@ilipreto.fr')),
              child: const Text(
                'contact@ilipreto.fr',
                textAlign: TextAlign.center,
                style: TextStyle(
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ConfidentialiteView extends StatelessWidget {
  const _ConfidentialiteView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Politique de confidentialité — iliprestō',
            style: theme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nous collectons le minimum de données nécessaires au '
            'fonctionnement de l’application et au respect de vos choix. '
            'Vous pouvez demander la suppression de vos données à tout moment.',
          ),
          const SizedBox(height: 16),
          Text(
            'Vos droits',
            style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('• Accès, rectification et suppression des données'),
          const Text('• Portabilité et limitation du traitement'),
          const Text('• Opposition et retrait du consentement'),
          const SizedBox(height: 16),
          Text(
            'Contact DPO',
            style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Center(
            child: InkWell(
              onTap: () => _launchUrl(Uri.parse('mailto:contact@ilipreto.fr')),
              child: const Text(
                'contact@ilipreto.fr',
                textAlign: TextAlign.center,
                style: TextStyle(decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CGUView extends StatelessWidget {
  const _CGUView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conditions Générales d’Utilisation (CGU)',
            style: theme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'L’utilisation de iliprestō implique l’acceptation des présentes CGU. '
            'Respect des utilisateurs, contenus licites et conformes, et usage '
            'responsable de la plateforme.',
          ),
          const SizedBox(height: 16),
          Text(
            'Principes clés',
            style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('• Respect de la loi et des autres utilisateurs'),
          const Text('• Interdiction des contenus contraires aux règles'),
          const Text('• Possibilité de modération et suppression de contenus'),
        ],
      ),
    );
  }
}

Future<void> _launchUrl(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
