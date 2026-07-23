import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/domain/publish_offer_form_policy.dart';

void main() {
  const validFixed = PublishOfferFormInput(
    title: 'Installer une étagère',
    description: 'Pose murale dans un salon',
    category: 'Bricolage / Travaux',
    location: 'Baie-Mahault',
    phone: '0690000000',
    missionDelay: 'Cette semaine',
    budget: '120 €',
    budgetType: 'Fixe',
  );

  test('canPublish accepte un formulaire complet avec budget fixe', () {
    expect(PublishOfferFormPolicy.canPublish(validFixed), isTrue);
    final readiness = PublishOfferFormPolicy.evaluate(validFixed);
    expect(readiness.parsedBudgetAmount, 120);
    expect(readiness.normalizedBudgetValue, '120');
    expect(readiness.firstInvalidFieldId, isNull);
  });

  test('canPublish refuse le premier champ obligatoire manquant', () {
    const invalid = PublishOfferFormInput(
      title: '   ',
      description: 'Description valide',
      category: 'Autre',
      location: 'Les Abymes',
      phone: '0690000000',
      missionDelay: 'Dès que possible',
      budget: '',
      budgetType: 'Fixe',
    );

    expect(PublishOfferFormPolicy.canPublish(invalid), isFalse);
    final readiness = PublishOfferFormPolicy.evaluate(invalid);
    expect(readiness.firstInvalidFieldId, PublishOfferFieldId.title);
    expect(
      readiness.issues.map((issue) => issue.fieldId),
      containsAll(<PublishOfferFieldId>[
        PublishOfferFieldId.title,
        PublishOfferFieldId.budget,
      ]),
    );
  });

  test('canPublish autorise un budget négocié vide', () {
    const negotiated = PublishOfferFormInput(
      title: 'Aide ponctuelle',
      description: 'Mission à définir ensemble',
      category: 'Aide à domicile',
      location: 'Petit-Bourg',
      phone: '0690000000',
      missionDelay: 'À convenir',
      budget: '',
      budgetType: 'À négocier',
    );

    expect(PublishOfferFormPolicy.canPublish(negotiated), isTrue);
    expect(
      PublishOfferFormPolicy.evaluate(negotiated).budgetType,
      PublishOfferBudgetType.negotiated,
    );
  });
}
