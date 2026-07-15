import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/journey_entitlements_service.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EntitlementsService extends JourneyEntitlementsService {
  _EntitlementsService(this.entitlements);

  final JourneyEntitlements entitlements;

  @override
  Future<JourneyEntitlements> resolveEntitlements() async => entitlements;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('resolveJourneyEntitlementsForAccess', () {
    test('le mode gratuit complet ouvre tous les quotas', () {
      for (final plan in SubscriptionPlan.values) {
        final entitlements = resolveJourneyEntitlementsForAccess(
          plan,
          freeAccessMode: true,
        );

        expect(entitlements.hasUnlimitedLocalSaves, isTrue);
        expect(entitlements.canExportPdf, isTrue);
        expect(entitlements.hasUnlimitedPdfExports, isTrue);
        expect(entitlements.pdfRequiresLogo, isTrue);
        expect(entitlements.pdfRequiresWatermark, isTrue);
      }
    });

    test('le plan Gratuit conserve deux sauvegardes et aucun PDF', () {
      final entitlements = resolveJourneyEntitlementsForAccess(
        SubscriptionPlan.free,
        freeAccessMode: false,
      );

      expect(entitlements.maxLocalSavesPerMonth, 2);
      expect(entitlements.canExportPdf, isFalse);
      expect(entitlements.maxPdfExportsPerMonth, 0);
      expect(entitlements.pdfRequiresLogo, isFalse);
      expect(entitlements.pdfRequiresWatermark, isFalse);
    });

    test('ilipresto+ et ilipro appliquent leurs quotas réels', () {
      final plus = resolveJourneyEntitlementsForAccess(
        SubscriptionPlan.iliprestoPlus,
        freeAccessMode: false,
      );
      final pro = resolveJourneyEntitlementsForAccess(
        SubscriptionPlan.ilipro,
        freeAccessMode: false,
      );

      expect(plus.maxLocalSavesPerMonth, 5);
      expect(plus.maxPdfExportsPerMonth, 5);
      expect(plus.canExportPdf, isTrue);
      expect(pro.maxLocalSavesPerMonth, 10);
      expect(pro.maxPdfExportsPerMonth, 10);
      expect(pro.canExportPdf, isTrue);
    });
  });

  group('compteurs mensuels locaux', () {
    test('les compteurs démarrent à zéro', () async {
      final service = _EntitlementsService(
        getJourneyEntitlementsForPlan(SubscriptionPlan.iliprestoPlus),
      );

      expect(await service.getLocalSavesUsedThisMonth(), 0);
      expect(await service.getPdfExportsUsedThisMonth(), 0);
    });

    test('recordLocalSave incrémente sans écraser le compteur', () async {
      final service = _EntitlementsService(
        getJourneyEntitlementsForPlan(SubscriptionPlan.ilipro),
      );

      await service.recordLocalSave();
      await service.recordLocalSave();

      expect(await service.getLocalSavesUsedThisMonth(), 2);
    });

    test('recordPdfExport incrémente le compteur PDF', () async {
      final service = _EntitlementsService(
        getJourneyEntitlementsForPlan(SubscriptionPlan.ilipro),
      );

      await service.recordPdfExport();
      await service.recordPdfExport();
      await service.recordPdfExport();

      expect(await service.getPdfExportsUsedThisMonth(), 3);
    });

    test('un compteur provenant d une ancienne période est ignoré', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'toolbox.journey_quota.saves_count': 9,
        'toolbox.journey_quota.saves_period': '2000-01',
        'toolbox.journey_quota.pdf_count': 8,
        'toolbox.journey_quota.pdf_period': '2000-01',
      });
      final service = _EntitlementsService(
        getJourneyEntitlementsForPlan(SubscriptionPlan.ilipro),
      );

      expect(await service.getLocalSavesUsedThisMonth(), 0);
      expect(await service.getPdfExportsUsedThisMonth(), 0);

      await service.recordLocalSave();
      await service.recordPdfExport();

      expect(await service.getLocalSavesUsedThisMonth(), 1);
      expect(await service.getPdfExportsUsedThisMonth(), 1);
    });
  });

  group('décisions de quota', () {
    test('autorise une sauvegarde tant que le quota n est pas atteint', () async {
      final service = _EntitlementsService(
        const JourneyEntitlements(
          maxLocalSavesPerMonth: 2,
          canExportPdf: false,
          maxPdfExportsPerMonth: 0,
          pdfRequiresLogo: false,
          pdfRequiresWatermark: false,
        ),
      );

      final first = await service.evaluateLocalSave();
      expect(first.allowed, isTrue);
      expect(first.usedThisMonth, 0);
      expect(first.entitlements.maxLocalSavesPerMonth, 2);

      await service.recordLocalSave();
      await service.recordLocalSave();
      final blocked = await service.evaluateLocalSave();
      expect(blocked.allowed, isFalse);
      expect(blocked.usedThisMonth, 2);
    });

    test('un plan sans PDF demande une mise à niveau', () async {
      final service = _EntitlementsService(
        getJourneyEntitlementsForPlan(SubscriptionPlan.free),
      );

      final decision = await service.evaluatePdfExport();

      expect(decision.allowed, isFalse);
      expect(decision.requiresUpgrade, isTrue);
      expect(decision.usedThisMonth, 0);
      expect(decision.entitlements.canExportPdf, isFalse);
    });

    test('autorise puis bloque les PDF lorsque le quota est atteint', () async {
      final service = _EntitlementsService(
        const JourneyEntitlements(
          maxLocalSavesPerMonth: 5,
          canExportPdf: true,
          maxPdfExportsPerMonth: 2,
          pdfRequiresLogo: true,
          pdfRequiresWatermark: true,
        ),
      );

      final initial = await service.evaluatePdfExport();
      expect(initial.allowed, isTrue);
      expect(initial.requiresUpgrade, isFalse);
      expect(initial.usedThisMonth, 0);

      await service.recordPdfExport();
      await service.recordPdfExport();
      final blocked = await service.evaluatePdfExport();
      expect(blocked.allowed, isFalse);
      expect(blocked.requiresUpgrade, isFalse);
      expect(blocked.usedThisMonth, 2);
    });

    test('les quotas illimités restent autorisés après plusieurs usages', () async {
      final service = _EntitlementsService(
        resolveJourneyEntitlementsForAccess(
          SubscriptionPlan.free,
          freeAccessMode: true,
        ),
      );

      for (var index = 0; index < 12; index += 1) {
        await service.recordLocalSave();
        await service.recordPdfExport();
      }

      expect((await service.evaluateLocalSave()).allowed, isTrue);
      expect((await service.evaluatePdfExport()).allowed, isTrue);
    });
  });
}
