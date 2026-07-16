import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/journey_pdf_export_service.dart';
import 'package:presto_app/services/parcours_fiches_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('préserve les informations riches et les risques de la fiche pilote',
      () async {
    final ficheFile = File(
      'docs/menu_activite_statuts/pack_fiches_fonctionnaire_firebase/json/'
      'fonctionnaire_aide_demenagement.json',
    );
    final markdownFile = File(
      'docs/menu_activite_statuts/pack_fiches_fonctionnaire_firebase/markdown/'
      'fonctionnaire_aide_demenagement.md',
    );

    final fiche = (jsonDecode(await ficheFile.readAsString()) as Map)
        .cast<String, dynamic>();
    fiche['markdown_content'] = await markdownFile.readAsString();

    final derived = mapFonctionnaireFicheToDerivedData(
      fiche: fiche,
      region: 'Guadeloupe',
      currentStatus: 'Fonctionnaire / agent public',
    );

    final steps = (derived['steps'] as List).cast<Map<String, dynamic>>();
    expect(
      steps.map((item) => '${item['id']}').toList(),
      const [
        'reglementation',
        'situation',
        'offres',
        'aides',
        'statut_lancement',
        'preparation',
        'declaration',
        'protections',
        'gestion',
        'lancement',
      ],
    );

    final regulationText = jsonEncode(derived['regulationTutorial']);
    for (final source in (fiche['sources_officielles'] as List).cast<String>()) {
      expect(regulationText, contains(source));
    }
    expect(regulationText, contains('registre électronique national'));
    expect(regulationText, contains('capacité professionnelle'));
    expect(regulationText, contains('capacité financière'));
    expect(regulationText, contains('licence adaptée'));

    final situationText = jsonEncode(derived['statusWarnings']);
    for (final phrase in const [
      'demande écrite d’autorisation de cumul',
      'réponse écrite de l’administration',
      'description des prestations avec ou sans transport',
      'pièce d’identité et justificatif de domicile',
      'devis d’assurance',
      'capacité professionnelle et financière',
      'estimation des revenus et de la périodicité',
      'inventaire du matériel',
      'projet de devis et de conditions d’intervention',
    ]) {
      expect(situationText, contains(phrase));
    }

    final costsText = jsonEncode(derived['costs']);
    for (final item in (fiche['couts_indicatifs'] as List).cast<String>()) {
      expect(costsText, contains(item));
    }
    for (final value in
        (fiche['fiscalite'] as Map).values.map((item) => '$item')) {
      expect(costsText, contains(value));
    }
    expect(costsText, contains('83 600 €'));
    expect(costsText, contains('21,2 %'));
    expect(costsText, contains('37 500 €'));
    expect(costsText, contains('41 250 €'));

    final fullText = jsonEncode(derived).toLowerCase();
    for (final requiredPhrase in const [
      'hors du périmètre des services à la personne',
      'transport routier de biens',
      'biens confiés',
      'dommages aux locaux',
      'port de charges',
      'travaux techniques',
      'guichet unique',
      'aides territoriales',
      'mission limitée',
    ]) {
      expect(fullText, contains(requiredPhrase));
    }
    for (final forbiddenPhrase in const [
      'nova sap',
      'publics fragiles',
      'actes de soin médical',
      'matériel de ménage',
    ]) {
      expect(fullText, isNot(contains(forbiddenPhrase)));
    }

    const pdfService = JourneyPdfExportService();
    final pdf = await pdfService.generateJourneyPdf({
      ...derived,
      'projectLabel': 'Démarrer une activité d’aide au déménagement',
      'region': 'Guadeloupe',
      'currentStatus': 'Fonctionnaire / agent public',
      'selectedActivity': 'Aide déménagement',
    });
    final bytes = await pdf.readAsBytes();
    final output =
        File('build/quality/parcours-guide-information-preservation.pdf');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes, flush: true);

    expect(bytes.length, greaterThan(10000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });
}
