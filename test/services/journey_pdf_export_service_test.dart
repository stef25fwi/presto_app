import 'dart:convert';
import 'dart:io';

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
        {
          'title': 'Source officielle',
          'description': 'https://entreprendre.service-public.fr/',
        },
      ],
      'statusWarnings': [
        {
          'title': 'Cumul avec un emploi salarié',
          'description':
              'Relire le contrat de travail et la clause de loyauté.',
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
          'id': 'reglementation',
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

  test('génère un PDF lorsque le contenu détaillé dépasse une page', () async {
    const service = JourneyPdfExportService();
    final file = await service.generateJourneyPdf({
      'projectLabel': 'Projet avec parcours détaillé',
      'region': 'Guadeloupe',
      'currentStatus': 'Fonctionnaire',
      'selectedActivity': 'Formation',
      'recommendation': {'statut': 'Micro-entreprise'},
      'steps': [
        {
          'id': 'reglementation',
          'title': 'Checklist complète',
          'description':
              'Cette étape longue vérifie la répartition sur plusieurs pages.',
          'todos': List<String>.generate(
            90,
            (index) =>
                'Action détaillée ${index + 1} : vérifier les documents, les règles et les justificatifs nécessaires.',
          ),
        },
      ],
    });

    final bytes = await file.readAsBytes();
    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });

  test('tolère les informations dupliquées et les blocs hétérogènes', () async {
    const service = JourneyPdfExportService();
    final file = await service.generateJourneyPdf({
      'projectLabel': 'Aide au déménagement',
      'region': 'Bretagne',
      'currentStatus': 'Salarié',
      'selectedActivity': 'Aide déménagement',
      'recommendation': {
        'statut': 'Micro-entreprise',
        'why': 'Démarrage progressif.',
      },
      'blockingAlerts': [
        'Relire le contrat de travail.',
        'Relire le contrat de travail.',
        'Vérifier la clause d’exclusivité ; vérifier la clause d’exclusivité.',
      ],
      'costs': {
        'formalitesEstimees': {'min': 0, 'max': 50},
        'ficheCoutsIndicatifs': [
          'RC pro : 100 à 300 €/an',
          'RC pro : 100 à 300 €/an',
        ],
      },
      'aides': [
        {'name': 'ACRE', 'desc': 'Exonération partielle de cotisations.'},
        {'name': 'ACRE', 'desc': 'Exonération partielle de cotisations.'},
      ],
      'plan30': [
        {'week': 'Semaine 1', 'label': 'Vérifier le contrat'},
        {'week': 'Semaine 1', 'label': 'Vérifier le contrat'},
      ],
      'steps': [
        {
          'id': 'situation',
          'title': 'Situation',
          'todos': ['Relire le contrat de travail.'],
        },
        {
          'id': 'protections',
          'title': 'Assurances',
          'todos': ['Demander un devis d’assurance professionnelle'],
        },
      ],
    });

    final bytes = await file.readAsBytes();
    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });

  test('produit un échantillon PDF pour le contrôle visuel CI', () async {
    const service = JourneyPdfExportService();
    final file = await service.generateJourneyPdf({
      'projectLabel': 'Démarrer une activité d’aide au déménagement',
      'region': 'Guadeloupe',
      'currentStatus': 'Fonctionnaire',
      'selectedActivity': 'Aide déménagement',
      'recommendation': {
        'statut': 'Micro-entreprise sous réserve du cumul',
        'why':
            'Adaptée à une activité accessoire limitée lorsque les frais restent maîtrisés.',
        'planB': 'Entreprise individuelle au réel si les frais sont importants.',
      },
      'blockingAlerts': [
        'Obtenir la décision écrite relative au cumul avant le démarrage.',
        'Distinguer la manutention seule du transport routier de biens.',
        'Obtenir une assurance couvrant les biens confiés et les locaux.',
      ],
      'summary': {
        'vigilanceLevel': 'Élevé si transport, moyen pour la manutention seule',
        'recommendedPath': 'Création progressive après vérifications',
      },
      'costs': {
        'formalitesEstimees': 'À vérifier sur le Guichet unique',
        'ficheCoutsIndicatifs': [
          'Assurance professionnelle adaptée au périmètre réel',
          'Équipements de protection et matériel de manutention',
          'Véhicule, carburant, entretien et stationnement',
        ],
      },
      'aides': [
        {
          'name': 'ACRE',
          'desc': 'Vérifier les conditions et le calendrier avant la création.',
        },
        {
          'name': 'Aides territoriales',
          'desc': 'Vérifier les dispositifs locaux avant l’immatriculation.',
        },
      ],
      'plan30': [
        {'week': 'Semaine 1', 'label': 'Définir le périmètre et sécuriser le cumul'},
        {'week': 'Semaine 2', 'label': 'Vérifier les aides, le budget et l’assurance'},
        {'week': 'Semaine 3', 'label': 'Préparer puis déposer la formalité'},
        {'week': 'Semaine 4', 'label': 'Lancer une première mission limitée'},
      ],
      'steps': [
        {
          'id': 'reglementation',
          'title': 'Vérifier le droit d’exercer',
          'objective':
              'Définir si la prestation comprend uniquement de la manutention ou également du transport.',
          'todos': [
            'Lister précisément les prestations',
            'Vérifier les obligations applicables au transport éventuel',
          ],
        },
        {
          'id': 'situation',
          'title': 'Sécuriser le cumul',
          'todos': [
            'Envoyer la demande à l’administration',
            'Conserver la réponse écrite',
          ],
        },
        {
          'id': 'aides',
          'title': 'Vérifier les aides avant la création',
          'todos': ['Contrôler l’ACRE et les dispositifs territoriaux'],
        },
        {
          'id': 'declaration',
          'title': 'Déclarer l’activité',
          'todos': ['Déposer la formalité au Guichet unique'],
        },
        {
          'id': 'protections',
          'title': 'Préparer la première mission',
          'todos': [
            'Activer l’assurance',
            'Préparer devis, facture et fiche d’inventaire',
          ],
        },
      ],
    });

    final bytes = await file.readAsBytes();
    final output = File('build/quality/parcours-guide-visual-sample.pdf');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes, flush: true);

    expect(await output.length(), greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });
}
