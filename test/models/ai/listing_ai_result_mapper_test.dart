import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/ai/audio_transcription_result.dart';
import 'package:presto_app/models/ai/listing_ai_result.dart';
import 'package:presto_app/services/ai/listing_ai_mapper.dart';

void main() {
  group('AudioTranscriptionResult', () {
    test('parse les valeurs et expose hasText', () {
      final result = AudioTranscriptionResult.fromMap(<String, dynamic>{
        'text': ' Bonjour ',
        'provider': 42,
        'languageCode': 'fr-FR',
        'storagePath': 123,
        'confidence': '0.91',
        'durationSeconds': 4,
      });

      expect(result.text, ' Bonjour ');
      expect(result.provider, '42');
      expect(result.languageCode, 'fr-FR');
      expect(result.storagePath, '123');
      expect(result.confidence, 0.91);
      expect(result.durationSeconds, 4.0);
      expect(result.hasText, isTrue);
    });

    test('gère les valeurs absentes ou invalides', () {
      final result = AudioTranscriptionResult.fromMap(<String, dynamic>{
        'text': '   ',
        'confidence': 'invalid',
        'durationSeconds': null,
      });

      expect(result.provider, '');
      expect(result.languageCode, '');
      expect(result.storagePath, isNull);
      expect(result.confidence, isNull);
      expect(result.durationSeconds, isNull);
      expect(result.hasText, isFalse);
    });

    test('convertit directement les valeurs numériques', () {
      final result = AudioTranscriptionResult.fromMap(<String, dynamic>{
        'confidence': 1,
        'durationSeconds': 2.5,
      });

      expect(result.confidence, 1.0);
      expect(result.durationSeconds, 2.5);
    });
  });

  group('ListingAiResult', () {
    const transcription = AudioTranscriptionResult(
      text: '  Je cherche un jardinier  ',
      provider: 'google',
      languageCode: 'fr-FR',
    );

    test('crée un résultat vide avec transcription', () {
      final result = ListingAiResult.empty(transcription: transcription);

      expect(result.title, '');
      expect(result.description, '');
      expect(result.transcription, transcription);
      expect(result.transcriptText, 'Je cherche un jardinier');
    });

    test('retourne un transcript vide sans transcription', () {
      final result = ListingAiResult.empty();

      expect(result.transcriptText, '');
    });

    test('normalise une réponse complète', () {
      final result = ListingAiResult.fromMap(
        <String, dynamic>{
          'title': '  Entretien jardin  ',
          'description': '  Taille et nettoyage  ',
          'category': ' Jardinage ',
          'price': '49.90',
          'currency': ' eur ',
          'city': ' Baie-Mahault ',
          'department': ' 971 ',
          'postalCode': ' 97122 ',
          'listingType': ' request ',
          'urgency': ' normal ',
          'contactPreference': ' chat ',
          'keywords': <dynamic>[' jardin ', '', 42],
          'details': <dynamic>[' taille ', ' nettoyage '],
          'missingFields': <dynamic>['photo', ' '],
          'questionsToAsk': <dynamic>['Quelle surface ?', ''],
          'confidenceScore': 0.87,
        },
        transcription: transcription,
      );

      expect(result.title, 'Entretien jardin');
      expect(result.description, 'Taille et nettoyage');
      expect(result.category, 'Jardinage');
      expect(result.price, 49.90);
      expect(result.currency, 'eur');
      expect(result.city, 'Baie-Mahault');
      expect(result.department, '971');
      expect(result.postalCode, '97122');
      expect(result.listingType, 'request');
      expect(result.urgency, 'normal');
      expect(result.contactPreference, 'chat');
      expect(result.keywords, <String>['jardin', '42']);
      expect(result.details, <String>['taille', 'nettoyage']);
      expect(result.missingFields, <String>['photo']);
      expect(result.questionsToAsk, <String>['Quelle surface ?']);
      expect(result.confidenceScore, 0.87);
      expect(result.transcriptText, 'Je cherche un jardinier');
    });

    test('gère les listes et nombres invalides', () {
      final result = ListingAiResult.fromMap(<String, dynamic>{
        'title': null,
        'description': null,
        'price': 'invalid',
        'confidenceScore': 'invalid',
        'keywords': 'not-a-list',
        'details': null,
        'missingFields': 42,
        'questionsToAsk': <dynamic>[],
      });

      expect(result.title, '');
      expect(result.description, '');
      expect(result.price, isNull);
      expect(result.confidenceScore, isNull);
      expect(result.keywords, isEmpty);
      expect(result.details, isEmpty);
      expect(result.missingFields, isEmpty);
      expect(result.questionsToAsk, isEmpty);
    });

    test('convertit un prix numérique', () {
      final result = ListingAiResult.fromMap(<String, dynamic>{
        'price': 75,
      });

      expect(result.price, 75.0);
    });

    test('produit un payload complet avec prix et transcription', () {
      const result = ListingAiResult(
        title: 'Peinture salon',
        description: 'Recherche peintre',
        category: 'Peinture',
        price: 250,
        currency: ' usd ',
        city: 'Pointe-à-Pitre',
        department: '971',
        postalCode: '97110',
        listingType: 'request',
        urgency: 'urgent',
        contactPreference: 'phone',
        keywords: <String>['peinture'],
        details: <String>['salon'],
        missingFields: <String>['photo'],
        questionsToAsk: <String>['Quelle date ?'],
        confidenceScore: 0.9,
        transcription: transcription,
      );

      final payload = result.toDraftPayload();

      expect(payload['title'], 'Peinture salon');
      expect(payload['titre'], 'Peinture salon');
      expect(payload['description'], 'Recherche peintre');
      expect(payload['description_courte'], 'Recherche peintre');
      expect(payload['category'], 'Peinture');
      expect(payload['categorie'], 'Peinture');
      expect(payload['city'], 'Pointe-à-Pitre');
      expect(payload['ville'], 'Pointe-à-Pitre');
      expect(payload['budgetType'], 'fixed');
      expect(payload['budget'], <String, dynamic>{
        'type': 'fixe',
        'min': 250,
        'max': 250,
        'devise': 'USD',
      });
      expect(payload['questions_a_poser'], <String>['Quelle date ?']);
      expect(payload['questionsToAsk'], <String>['Quelle date ?']);
      expect(payload['transcript'], '  Je cherche un jardinier  ');
    });

    test('utilise EUR et un budget vide sans prix', () {
      const result = ListingAiResult(
        title: '',
        description: '',
        currency: '   ',
      );

      final payload = result.toDraftPayload();

      expect(payload['budgetType'], isNull);
      expect(payload['budget'], <String, dynamic>{
        'type': null,
        'min': null,
        'max': null,
        'devise': 'EUR',
      });
      expect(payload.containsKey('transcript'), isFalse);
    });

    test('utilise EUR lorsque la devise est absente', () {
      const result = ListingAiResult(
        title: '',
        description: '',
      );

      final payload = result.toDraftPayload();
      final budget = payload['budget']! as Map<String, dynamic>;

      expect(budget['devise'], 'EUR');
    });
  });

  group('ListingAiMapper', () {
    test('lit un résultat texte imbriqué', () {
      final result = ListingAiMapper.fromTextCallableResponse(
        <String, dynamic>{
          'result': <String, dynamic>{
            'title': ' Jardinage ',
            'description': ' Entretien ',
          },
        },
      );

      expect(result.title, 'Jardinage');
      expect(result.description, 'Entretien');
    });

    test('utilise la réponse racine sans résultat imbriqué', () {
      final result = ListingAiMapper.fromTextCallableResponse(
        <String, dynamic>{
          'title': 'Bricolage',
          'description': 'Montage meuble',
        },
      );

      expect(result.title, 'Bricolage');
      expect(result.description, 'Montage meuble');
    });

    test('ignore un résultat imbriqué mal typé', () {
      final result = ListingAiMapper.fromTextCallableResponse(
        <String, dynamic>{
          'result': 'invalid',
          'title': 'Direct',
          'description': 'Fallback',
        },
      );

      expect(result.title, 'Direct');
      expect(result.description, 'Fallback');
    });

    test('mappe une réponse audio avec transcription', () {
      final result = ListingAiMapper.fromAudioCallableResponse(
        <String, dynamic>{
          'result': <dynamic, dynamic>{
            'title': 'Nettoyage',
            'description': 'Nettoyage terrasse',
          },
          'transcription': <dynamic, dynamic>{
            'text': 'Nettoyer ma terrasse',
            'provider': 'google',
            'languageCode': 'fr-FR',
            'confidence': '0.95',
          },
        },
      );

      expect(result.title, 'Nettoyage');
      expect(result.transcription, isNotNull);
      expect(result.transcription!.text, 'Nettoyer ma terrasse');
      expect(result.transcription!.confidence, 0.95);
    });

    test('ne crée pas de transcription avec une valeur vide ou invalide', () {
      final empty = ListingAiMapper.fromAudioCallableResponse(
        <String, dynamic>{
          'title': 'Test',
          'transcription': <String, dynamic>{},
        },
      );

      final invalid = ListingAiMapper.fromAudioCallableResponse(
        <String, dynamic>{
          'title': 'Test',
          'transcription': 'invalid',
        },
      );

      expect(empty.transcription, isNull);
      expect(invalid.transcription, isNull);
    });

    test('délègue la création du brouillon', () {
      const result = ListingAiResult(
        title: 'Annonce',
        description: 'Description',
        price: 10,
      );

      final payload = ListingAiMapper.toPublishDraft(result);

      expect(payload['title'], 'Annonce');
      expect(payload['budgetType'], 'fixed');
    });
  });
}
