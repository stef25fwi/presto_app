import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/ai_draft/ai_draft_service.dart';

void main() {
  test('prépare la session, transmet les paramètres et normalise le résultat',
      () async {
    var prepared = 0;
    Map<String, dynamic>? received;
    final service = AiDraftService(
      sessionPreparer: () async => prepared++,
      callable: (parameters) async {
        received = parameters;
        return <dynamic, dynamic>{
          'title': 'Titre historique',
          'categorie': 'Jardinage',
          'description': 'Tailler une haie',
          'commune': 'Petit-Bourg',
          'cp': 97170,
          'titre': 'Besoin d aide au jardin',
          'suggestions_titres': <dynamic>['Titre A', 2],
          'description_courte': 'Une haie à tailler',
          'sous_categorie': 'Taille de haie',
          'ville': 'Petit-Bourg',
          'secteur': 'Centre',
          'budget': <dynamic, dynamic>{'min': 40, 'max': 60},
          'urgence': 'Cette semaine',
          'details': <dynamic>['Haie de 8 mètres'],
          'competences_requises': <dynamic>['Jardinage'],
          'materiel': <dynamic, dynamic>{'fourni': true},
          'disponibilites': 'Samedi matin',
          'questions_a_poser': <dynamic>['Avez-vous une échelle ?'],
        };
      },
    );

    final result = await service.generateOfferDraftV2(
      text: 'Je cherche une personne pour tailler ma haie',
      city: 'Petit-Bourg',
      category: 'Jardinage',
    );

    expect(prepared, 1);
    expect(received?['hint'], 'Je cherche une personne pour tailler ma haie');
    expect(received?['city'], 'Petit-Bourg');
    expect(received?['category'], 'Jardinage');
    expect(received?['clientRequestId'], startsWith('text_'));
    expect(result['success'], isTrue);
    expect(result['title'], 'Titre historique');
    expect(result['category'], 'Jardinage');
    expect(result['location'], 'Petit-Bourg');
    expect(result['postalCode'], '97170');
    expect(result['suggestions_titres'], <String>['Titre A', '2']);
    expect(result['budget'], <String, dynamic>{'min': 40, 'max': 60});
    expect(result['materiel'], <String, dynamic>{'fourni': true});
  });

  test('omet ville et catégorie nulles et applique les replis sûrs', () async {
    Map<String, dynamic>? received;
    final service = AiDraftService(
      sessionPreparer: () async {},
      callable: (parameters) async {
        received = parameters;
        return <dynamic, dynamic>{
          'catégorie': 'Bricolage',
          'location': 'Les Abymes',
          'postal_code': '97139',
          'suggestions_titres': 'pas une liste',
          'budget': 'invalide',
          'materiel': null,
          'details': null,
        };
      },
    );

    final result = await service.generateOfferDraftV2(text: 'Réparer une porte');

    expect(received, isNot(contains('city')));
    expect(received, isNot(contains('category')));
    expect(result['category'], 'Bricolage');
    expect(result['location'], 'Les Abymes');
    expect(result['postalCode'], '97139');
    expect(result['suggestions_titres'], isEmpty);
    expect(result['budget'], isEmpty);
    expect(result['materiel'], isEmpty);
    expect(result['details'], isEmpty);
  });

  test('retourne le code et le message d une erreur Functions', () async {
    final service = AiDraftService(
      sessionPreparer: () async {},
      callable: (_) async => throw FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Accès refusé',
      ),
    );

    final result = await service.generateOfferDraftV2(text: 'Annonce');

    expect(result, containsPair('success', false));
    expect(result, containsPair('code', 'permission-denied'));
    expect(result, containsPair('error', 'Accès refusé'));
  });

  test('convertit une erreur inconnue en résultat exploitable', () async {
    final service = AiDraftService(
      sessionPreparer: () async {},
      callable: (_) async => throw StateError('payload invalide'),
    );

    final result = await service.generateOfferDraftV2(text: 'Annonce');

    expect(result['success'], isFalse);
    expect(result['error'], contains('payload invalide'));
    expect(result, isNot(contains('code')));
  });
}
