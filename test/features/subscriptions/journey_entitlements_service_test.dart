import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/journey_entitlements_service.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

void main() {
  group('resolveJourneyEntitlementsForAccess', () {
    test('ouvre les sauvegardes et PDF en accès gratuit complet', () {
      for (final plan in SubscriptionPlan.values) {
        final rights = resolveJourneyEntitlementsForAccess(
          plan,
          freeAccessMode: true,
        );

        expect(rights.canExportPdf, isTrue, reason: plan.name);
        expect(rights.hasUnlimitedLocalSaves, isTrue, reason: plan.name);
        expect(rights.hasUnlimitedPdfExports, isTrue, reason: plan.name);
        expect(rights.pdfRequiresLogo, isTrue, reason: plan.name);
        expect(rights.pdfRequiresWatermark, isTrue, reason: plan.name);
      }
    });

    test('conserve les limites du plan quand le mode gratuit est désactivé', () {
      final freeRights = resolveJourneyEntitlementsForAccess(
        SubscriptionPlan.free,
        freeAccessMode: false,
      );
      final plusRights = resolveJourneyEntitlementsForAccess(
        SubscriptionPlan.iliprestoPlus,
        freeAccessMode: false,
      );
      final proRights = resolveJourneyEntitlementsForAccess(
        SubscriptionPlan.ilipro,
        freeAccessMode: false,
      );

      expect(freeRights.canExportPdf, isFalse);
      expect(freeRights.maxPdfExportsPerMonth, 0);
      expect(
        plusRights.maxPdfExportsPerMonth,
        kIliPrestoPlusJourneyPdfExportQuotaPerMonth,
      );
      expect(
        proRights.maxPdfExportsPerMonth,
        kIliProJourneyPdfExportQuotaPerMonth,
      );
    });
  });
}
