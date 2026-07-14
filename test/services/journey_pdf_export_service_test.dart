import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/journey_pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('génère un fichier PDF valide avec les données du parcours', () async {
    const service = JourneyPdfExportService();
    final file = await service.generateJourneyPdf({
      'projectLabel': 'Créer une activité de pâtisserie artisanale',
      'region': 'Guadeloupe',
      'currentStatus': 'Salarié',
      'selectedActivity': 'Pâtisserie',
      'recommendation': {
        'statut': 'Micro-entreprise',
        'why': 'Un cadre simple pour tester l’activité et démarrer rapidement.',
        'planB': 'Entreprise individuelle au réel',
      },
      'blockingAlerts': [
        'Vérifier les règles d’hygiène alimentaire.',
      ],
      'costs': {
        'formalitesEstimees': {'min': 0, 'max': 50},
        'assuranceProAn': 180,
      },
      'summary': {
        'vigilanceLevel': 'Moyen',
        'recommendedPath': 'Démarrage progressif',
      },
      'recommendedLegalStatus': {
        'recommended': 'Micro-entreprise',
        'justification': 'Adaptée à un lancement avec peu de charges fixes.',
      },
      'regulationTutorial': [
        {
          'title': 'Hygiène alimentaire',
          'description':
              'Vérifier la formation, les locaux et la conservation des produits.',
        },
      ],
      'statusWarnings': [
        {
          'title': 'Cumul avec un emploi salarié',
          'description': 'Relire le contrat de travail et la clause de loyauté.',
          'checks': ['Absence de clause d’exclusivité incompatible'],
        },
      ],
      'aides': [
        {
          'name': 'Aide régionale',
          'desc': 'Vérifier les dispositifs ouverts en Guadeloupe.',
        },
      ],
      'plan30': [
        {
          'week': 'Semaine 1',
          'label': 'Valider le projet et le budget',
        },
      ],
      'steps': [
        {
          'title': 'Préparer le lancement',
          'objective': 'Réunir les documents utiles.',
          'todos': [
            'Préparer une pièce d’identité',
            'Choisir une assurance professionnelle',
          ],
        },
      ],
    });

    final bytes = await file.readAsBytes();

    // Le nom d'un XFile.fromData n'est pas exposé de façon uniforme par
    // cross_file sur tous les runners. Le contenu est le contrat portable.
    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });
}
