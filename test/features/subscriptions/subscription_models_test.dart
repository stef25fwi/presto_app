import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';
import 'package:presto_app/features/subscriptions/subscription_plan_key.dart';

void main() {
  group('SubscriptionPlanKey', () {
    test('normalise les alias historiques', () {
      expect(subscriptionPlanKeyFromId('free'), SubscriptionPlanKey.free);
      expect(subscriptionPlanKeyFromId('gratuit'), SubscriptionPlanKey.free);
      expect(
        subscriptionPlanKeyFromId('ilipresto_plus'),
        SubscriptionPlanKey.iliPrestoPlus,
      );
      expect(
        subscriptionPlanKeyFromId('ilipresto+'),
        SubscriptionPlanKey.iliPrestoPlus,
      );
      expect(subscriptionPlanKeyFromId('pro'), SubscriptionPlanKey.iliPro);
      expect(subscriptionPlanKeyFromId('inconnu'), SubscriptionPlanKey.free);
    });
  });

  group('features par plan', () {
    test('gratuit applique les limites les plus strictes', () {
      final features = getFeaturesForSubscriptionPlan(SubscriptionPlanKey.free);

      expect(features.maxActiveOffers, 3);
      expect(features.photosPerOffer, 1);
      expect(features.aiDraftsPerMonth, 2);
      expect(features.voiceAiDraftsPerMonth, 1);
      expect(features.favoriteAlertsEnabled, isFalse);
      expect(features.analyticsEnabled, isFalse);
      expect(features.proProfileEnabled, isFalse);
      expect(features.savedJourneysPerMonth, 1);
      expect(features.pdfExportsPerMonth, 0);
    });

    test('iliprestō+ active les alertes et exports limités', () {
      final features = getFeaturesForSubscriptionPlan(
        SubscriptionPlanKey.iliPrestoPlus,
      );

      expect(features.maxActiveOffers, 10);
      expect(features.photosPerOffer, 3);
      expect(features.aiDraftsPerMonth, 30);
      expect(features.voiceAiDraftsPerMonth, 10);
      expect(features.favoriteAlertsEnabled, isTrue);
      expect(features.pdfExportsPerMonth, 2);
      expect(features.proProfileEnabled, isFalse);
    });

    test('ilipro conserve les capacités professionnelles', () {
      final features = getFeaturesForSubscriptionPlan(
        SubscriptionPlanKey.iliPro,
      );

      expect(features.maxActiveOffers, 30);
      expect(features.photosPerOffer, 10);
      expect(features.aiDraftsPerMonth, -1);
      expect(features.voiceAiDraftsPerMonth, -1);
      expect(features.analyticsEnabled, isTrue);
      expect(features.proProfileEnabled, isTrue);
      expect(features.pdfExportsPerMonth, -1);
    });
  });

  group('SubscriptionUsage', () {
    SubscriptionUsage usage({
      int pdfExports = 0,
      int journeys = 0,
    }) {
      final now = DateTime.utc(2026, 7, 11);
      return SubscriptionUsage(
        userId: 'user-1',
        period: '2026-07',
        aiDraftsUsed: 0,
        voiceAiDraftsUsed: 0,
        journeysCreated: journeys,
        pdfExports: pdfExports,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('quota PDF gratuit reste bloqué', () {
      expect(
        usage().canExportPdf(getFeaturesForSubscriptionPlan(
          SubscriptionPlanKey.free,
        )),
        isFalse,
      );
    });

    test('quota iliprestō+ autorise deux exports puis bloque', () {
      final features = getFeaturesForSubscriptionPlan(
        SubscriptionPlanKey.iliPrestoPlus,
      );
      expect(usage(pdfExports: 0).canExportPdf(features), isTrue);
      expect(usage(pdfExports: 1).canExportPdf(features), isTrue);
      expect(usage(pdfExports: 2).canExportPdf(features), isFalse);
    });

    test('quota illimité accepte toute consommation positive', () {
      final features = getFeaturesForSubscriptionPlan(
        SubscriptionPlanKey.iliPro,
      );
      expect(usage(pdfExports: 10_000).canExportPdf(features), isTrue);
    });

    test('copyWith et JSON conservent les compteurs', () {
      final original = usage(pdfExports: 1, journeys: 1);
      final updated = original.copyWith(pdfExports: 2);
      final restored = SubscriptionUsage.fromJson(updated.toJson());

      expect(updated.journeysCreated, 1);
      expect(restored.pdfExports, 2);
      expect(restored.period, '2026-07');
    });
  });

  group('SubscriptionPurchase', () {
    test('sérialise et restaure une transaction confirmée', () {
      final createdAt = DateTime.utc(2026, 7, 11, 12);
      final purchase = SubscriptionPurchase(
        id: 'purchase-1',
        userId: 'user-1',
        plan: 'ilipresto_plus',
        amount: 1.99,
        currency: 'EUR',
        status: 'completed',
        transactionId: 'txn-1',
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      final restored = SubscriptionPurchase.fromJson(purchase.toJson());

      expect(restored.id, 'purchase-1');
      expect(restored.plan, 'ilipresto_plus');
      expect(restored.amount, 1.99);
      expect(restored.status, 'completed');
      expect(restored.transactionId, 'txn-1');
    });
  });
}
