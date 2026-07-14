import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/domain/publish_offer_form_policy.dart';

void main() {
  group('PublishOfferFormPolicy.evaluate', () {
    test('autorise un formulaire complet avec budget fixe', () {
      final readiness = PublishOfferFormPolicy.evaluate(
        const PublishOfferFormInput(
          title: 'Pose étagère',
          description: 'Fixer deux étagères dans le salon.',
          category: 'Bricolage',
          location: 'Baie-Mahault',
          phone: '0690123456',
          missionDelay: 'Sous 48h',
          budget: '75,50 €',
          budgetType: 'Fixe',
        ),
      );

      expect(readiness.isValid, isTrue);
      expect(readiness.issues, isEmpty);
      expect(readiness.firstInvalidFieldId, isNull);
      expect(readiness.budgetType, PublishOfferBudgetType.fixed);
      expect(readiness.parsedBudgetAmount, 75.5);
      expect(readiness.normalizedBudgetValue, '75.50');
    });

    test('autorise un budget a negocier sans montant', () {
      final readiness = PublishOfferFormPolicy.evaluate(
        const PublishOfferFormInput(
          title: 'Nettoyage jardin',
          description: 'Débroussailler un petit terrain.',
          category: 'Jardinage',
          location: 'Petit-Bourg',
          phone: '0690123456',
          missionDelay: 'À convenir',
          budget: '',
          budgetType: 'À négocier',
        ),
      );

      expect(readiness.isValid, isTrue);
      expect(readiness.budgetType, PublishOfferBudgetType.negotiated);
      expect(readiness.parsedBudgetAmount, isNull);
    });

    test('remonte tous les champs obligatoires manquants dans l ordre UI', () {
      final readiness = PublishOfferFormPolicy.evaluate(
        const PublishOfferFormInput(
          title: ' ',
          description: '',
          category: null,
          location: ' ',
          phone: '',
          missionDelay: null,
          budget: '',
          budgetType: 'Fixe',
        ),
      );

      expect(readiness.isValid, isFalse);
      expect(readiness.firstInvalidFieldId, PublishOfferFieldId.title);
      expect(
        readiness.issues.map((issue) => issue.fieldId),
        const [
          PublishOfferFieldId.title,
          PublishOfferFieldId.description,
          PublishOfferFieldId.category,
          PublishOfferFieldId.location,
          PublishOfferFieldId.phone,
          PublishOfferFieldId.missionDelay,
          PublishOfferFieldId.budget,
        ],
      );
    });

    test('refuse un budget fixe non positif ou non numerique', () {
      for (final value in ['abc', '0', '-5', '0 €']) {
        final readiness = PublishOfferFormPolicy.evaluate(
          PublishOfferFormInput(
            title: 'Pose étagère',
            description: 'Fixer deux étagères dans le salon.',
            category: 'Bricolage',
            location: 'Baie-Mahault',
            phone: '0690123456',
            missionDelay: 'Sous 48h',
            budget: value,
            budgetType: 'Fixe',
          ),
        );

        expect(readiness.isValid, isFalse, reason: value);
        expect(readiness.firstInvalidFieldId, PublishOfferFieldId.budget);
        expect(readiness.parsedBudgetAmount, isNull);
      }
    });

    test('normalise les variantes de type budget', () {
      expect(
        PublishOfferFormPolicy.normalizeBudgetType('Fixe'),
        PublishOfferBudgetType.fixed,
      );
      expect(
        PublishOfferFormPolicy.normalizeBudgetType('a negocier'),
        PublishOfferBudgetType.negotiated,
      );
      expect(
        PublishOfferFormPolicy.normalizeBudgetType('negotiated'),
        PublishOfferBudgetType.negotiated,
      );
    });
  });
}
