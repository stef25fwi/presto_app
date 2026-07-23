import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/journey_entitlements_service.dart';
import 'package:presto_app/features/subscriptions/subscription_credit_service.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

class _FakeCreditService extends SubscriptionCreditService {
  _FakeCreditService(this.snapshot);

  SubscriptionCreditSnapshot snapshot;

  @override
  Future<SubscriptionCreditSnapshot> getSnapshot() async => snapshot;
}

class _ThrowingCreditService extends SubscriptionCreditService {
  @override
  Future<SubscriptionCreditSnapshot> getSnapshot() async {
    throw StateError('snapshot unavailable');
  }
}

class _EntitlementsService extends JourneyEntitlementsService {
  _EntitlementsService(this.entitlements, SubscriptionCreditSnapshot snapshot)
      : super(creditService: _FakeCreditService(snapshot));

  final JourneyEntitlements entitlements;

  @override
  Future<JourneyEntitlements> resolveEntitlements() async => entitlements;
}

class _ThrowingEntitlementsService extends JourneyEntitlementsService {
  _ThrowingEntitlementsService(this.entitlements)
      : super(creditService: _ThrowingCreditService());

  final JourneyEntitlements entitlements;

  @override
  Future<JourneyEntitlements> resolveEntitlements() async => entitlements;
}

SubscriptionCreditStatus _credit({
  required int used,
  required int limit,
  bool unlimited = false,
}) {
  return SubscriptionCreditStatus(
    used: used,
    limit: limit,
    remaining: unlimited ? 999999 : (used >= limit ? 0 : limit - used),
    unlimited: unlimited,
    exhausted: !unlimited && used >= limit,
  );
}

SubscriptionCreditSnapshot _snapshot({
  int journeysUsed = 0,
  int journeysLimit = 5,
  int pdfUsed = 0,
  int pdfLimit = 5,
  bool unlimited = false,
}) {
  return SubscriptionCreditSnapshot(
    plan: 'ilipresto_plus',
    period: '2026-07',
    freeAccessMode: unlimited,
    nextResetAt: DateTime.utc(2026, 8),
    credits: {
      SubscriptionCreditKind.journeys: _credit(
        used: journeysUsed,
        limit: unlimited ? 999999 : journeysLimit,
        unlimited: unlimited,
      ),
      SubscriptionCreditKind.pdf: _credit(
        used: pdfUsed,
        limit: unlimited ? 999999 : pdfLimit,
        unlimited: unlimited,
      ),
      SubscriptionCreditKind.voiceAi: _credit(
        used: 0,
        limit: unlimited ? 999999 : 5,
        unlimited: unlimited,
      ),
      SubscriptionCreditKind.textAi: _credit(
        used: 0,
        limit: 999999,
        unlimited: true,
      ),
      SubscriptionCreditKind.activeOffers: _credit(
        used: 1,
        limit: unlimited ? 999999 : 10,
        unlimited: unlimited,
      ),
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
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

    test('le plan Gratuit conserve deux parcours et aucun PDF', () {
      final entitlements = resolveJourneyEntitlementsForAccess(
        SubscriptionPlan.free,
        freeAccessMode: false,
      );
      expect(entitlements.maxLocalSavesPerMonth, 2);
      expect(entitlements.canExportPdf, isFalse);
      expect(entitlements.maxPdfExportsPerMonth, 0);
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
      expect(pro.maxLocalSavesPerMonth, 10);
      expect(pro.maxPdfExportsPerMonth, 10);
    });
  });

  group('compteurs Firestore partagés', () {
    test('expose les utilisations de la bibliothèque et des PDF', () async {
      final service = _EntitlementsService(
        getJourneyEntitlementsForPlan(SubscriptionPlan.iliprestoPlus),
        _snapshot(journeysUsed: 3, pdfUsed: 2),
      );
      expect(await service.getLocalSavesUsedThisMonth(), 3);
      expect(await service.getPdfExportsUsedThisMonth(), 2);
    });

    test('retombe à zéro quand le snapshot serveur échoue', () async {
      final service = _ThrowingEntitlementsService(
        getJourneyEntitlementsForPlan(SubscriptionPlan.iliprestoPlus),
      );

      expect(await service.getLocalSavesUsedThisMonth(), 0);
      expect(await service.getPdfExportsUsedThisMonth(), 0);
      final saveDecision = await service.evaluateLocalSave();
      final pdfDecision = await service.evaluatePdfExport();
      expect(saveDecision.allowed, isTrue);
      expect(saveDecision.usedThisMonth, 0);
      expect(pdfDecision.allowed, isTrue);
      expect(pdfDecision.usedThisMonth, 0);
    });

    test('autorise la bibliothèque tant qu une place reste disponible', () async {
      final service = _EntitlementsService(
        getJourneyEntitlementsForPlan(SubscriptionPlan.iliprestoPlus),
        _snapshot(journeysUsed: 4),
      );
      final decision = await service.evaluateLocalSave();
      expect(decision.allowed, isTrue);
      expect(decision.usedThisMonth, 4);
    });

    test('bloque la bibliothèque uniquement quand la capacité est atteinte', () async {
      final service = _EntitlementsService(
        getJourneyEntitlementsForPlan(SubscriptionPlan.iliprestoPlus),
        _snapshot(journeysUsed: 5),
      );
      final decision = await service.evaluateLocalSave();
      expect(decision.allowed, isFalse);
      expect(decision.usedThisMonth, 5);
    });

    test('un plan sans PDF demande une mise à niveau', () async {
      final service = _EntitlementsService(
        getJourneyEntitlementsForPlan(SubscriptionPlan.free),
        _snapshot(pdfLimit: 0),
      );
      final decision = await service.evaluatePdfExport();
      expect(decision.allowed, isFalse);
      expect(decision.requiresUpgrade, isTrue);
    });

    test('bloque les PDF uniquement lorsque le compteur serveur est plein', () async {
      final service = _EntitlementsService(
        getJourneyEntitlementsForPlan(SubscriptionPlan.iliprestoPlus),
        _snapshot(pdfUsed: 5),
      );
      final decision = await service.evaluatePdfExport();
      expect(decision.allowed, isFalse);
      expect(decision.requiresUpgrade, isFalse);
      expect(decision.usedThisMonth, 5);
    });

    test('les crédits illimités restent disponibles', () async {
      final service = _EntitlementsService(
        resolveJourneyEntitlementsForAccess(
          SubscriptionPlan.free,
          freeAccessMode: true,
        ),
        _snapshot(
          journeysUsed: 120,
          pdfUsed: 80,
          unlimited: true,
        ),
      );
      expect((await service.evaluateLocalSave()).allowed, isTrue);
      expect((await service.evaluatePdfExport()).allowed, isTrue);
    });

    test('les anciennes méthodes record ne doublent pas le débit serveur', () async {
      final service = _EntitlementsService(
        getJourneyEntitlementsForPlan(SubscriptionPlan.iliprestoPlus),
        _snapshot(journeysUsed: 2, pdfUsed: 1),
      );
      await service.recordLocalSave();
      await service.recordPdfExport();
      expect(await service.getLocalSavesUsedThisMonth(), 2);
      expect(await service.getPdfExportsUsedThisMonth(), 1);
    });
  });
}
