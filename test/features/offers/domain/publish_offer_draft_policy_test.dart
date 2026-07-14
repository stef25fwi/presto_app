import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/domain/publish_offer_draft_policy.dart';

void main() {
  group('PublishOfferDraftPolicy.normalizeDraftMissionDelay', () {
    test('mappe les urgences IA connues vers les libelles formulaire', () {
      const expected = <String, String>{
        'immediat': 'Urgent',
        '24h': 'Dans la journée',
        'demain': 'Demain',
        '48h': 'Sous 48h',
        '7j': 'Cette semaine',
        'flexible': 'À convenir',
      };

      for (final entry in expected.entries) {
        expect(
          PublishOfferDraftPolicy.normalizeDraftMissionDelay(entry.key),
          entry.value,
          reason: entry.key,
        );
      }

      expect(PublishOfferDraftPolicy.normalizeDraftMissionDelay(''), isNull);
      expect(PublishOfferDraftPolicy.normalizeDraftMissionDelay(null), isNull);
    });
  });

  group('PublishOfferDraftPolicy transcript signals', () {
    test('detecte les budgets explicites et les budgets negocies', () {
      expect(
        PublishOfferDraftPolicy.transcriptMentionsBudget(
          'Je peux payer 120 euros pour la mission.',
        ),
        isTrue,
      );
      expect(
        PublishOfferDraftPolicy.transcriptMentionsBudget(
          'Le prix est à négocier selon le trajet.',
        ),
        isTrue,
      );
      expect(
        PublishOfferDraftPolicy.transcriptMentionsBudget(
          'J’ai besoin d’aide pour le jardin.',
        ),
        isFalse,
      );

      expect(
        PublishOfferDraftPolicy.transcriptRequestsNegotiatedBudget(
          'Budget flexible, à discuter sur place.',
        ),
        isTrue,
      );
      expect(
        PublishOfferDraftPolicy.transcriptRequestsNegotiatedBudget(
          'Budget fixe de 90 euros.',
        ),
        isFalse,
      );
    });

    test('detecte les urgences et extrait le delai formulaire', () {
      const expected = <String, String>{
        'C’est urgent pour ce soir.': 'Urgent',
        'Besoin aujourd hui dans la journee.': 'Dans la journée',
        'Intervention demain matin.': 'Demain',
        'Mission sous 48h si possible.': 'Sous 48h',
        'Disponible cette semaine.': 'Cette semaine',
        'Pas urgent, à convenir.': 'À convenir',
      };

      for (final entry in expected.entries) {
        expect(
          PublishOfferDraftPolicy.transcriptMentionsUrgency(entry.key),
          isTrue,
          reason: entry.key,
        );
        expect(
          PublishOfferDraftPolicy.extractMissionDelayFromTranscript(entry.key),
          entry.value,
          reason: entry.key,
        );
      }

      expect(
        PublishOfferDraftPolicy.extractMissionDelayFromTranscript(
          'Je cherche une aide pour nettoyer une terrasse.',
        ),
        isNull,
      );
    });

    test('extrait le premier montant budget positif', () {
      expect(
        PublishOfferDraftPolicy.extractBudgetAmountFromTranscript(
          'Je propose 75,50 euros pour la prestation.',
        ),
        75.5,
      );
      expect(
        PublishOfferDraftPolicy.extractBudgetAmountFromTranscript(
          'Budget 0 euros puis 80 euros.',
        ),
        80,
      );
      expect(
        PublishOfferDraftPolicy.extractBudgetAmountFromTranscript(
          'Prix à négocier.',
        ),
        isNull,
      );
    });
  });

  group('PublishOfferDraftPolicy rich draft description', () {
    test('filtre les details qui repetent la description', () {
      final kept = PublishOfferDraftPolicy.filterRedundantDetails(
        'Recherche réparation fuite cuisine à Baie-Mahault.',
        const [
          'Réparer la fuite dans la cuisine',
          'Prévoir joints et petit matériel',
          'Disponible samedi matin',
        ],
      );

      expect(kept, const [
        'Prévoir joints et petit matériel',
        'Disponible samedi matin',
      ]);
    });

    test('construit une description enrichie lisible', () {
      final description = PublishOfferDraftPolicy.buildRichDraftDescription({
        'description_courte': 'Cherche jardinier pour nettoyer le terrain.',
        'details': [
          'Nettoyer le terrain',
          'Apporter débroussailleuse',
          '',
        ],
        'disponibilites': 'Samedi matin',
      });

      expect(
        description,
        'Cherche jardinier pour nettoyer le terrain.\n'
        '- Apporter débroussailleuse\n'
        'Disponibilités : Samedi matin',
      );
    });

    test('retourne la premiere valeur non vide du brouillon', () {
      expect(
        PublishOfferDraftPolicy.firstNonEmptyDraftValue(
          {'title': ' ', 'titre': 'Pose étagère'},
          const ['title', 'titre'],
        ),
        'Pose étagère',
      );
      expect(
        PublishOfferDraftPolicy.firstNonEmptyDraftValue({}, const ['title']),
        '',
      );
    });
  });
}
