import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'subscription_config_service.dart';
import 'subscription_credit_service.dart';
import 'subscription_models.dart';

/// Résout les droits du parcours à partir du plan réel et du mode d'accès
/// global piloté depuis l'administration.
JourneyEntitlements resolveJourneyEntitlementsForAccess(
  SubscriptionPlan plan, {
  required bool freeAccessMode,
}) {
  if (freeAccessMode) {
    return const JourneyEntitlements(
      maxLocalSavesPerMonth: kUnlimitedJourneyQuota,
      canExportPdf: true,
      maxPdfExportsPerMonth: kUnlimitedJourneyQuota,
      pdfRequiresLogo: true,
      pdfRequiresWatermark: true,
    );
  }

  return getJourneyEntitlementsForPlan(
    plan,
    freeAccessMode: false,
  );
}

/// Compatibilité avec les écrans historiques du parcours.
///
/// Les compteurs ne sont plus stockés dans SharedPreferences : la source de
/// vérité est désormais le service Firestore `SubscriptionCreditService`,
/// partagé entre tous les appareils. Les anciennes méthodes `record*` restent
/// présentes mais sont volontairement sans effet :
/// - la bibliothèque est débitée atomiquement par `saveMyJourney` ;
/// - le PDF est réservé par `saveJourneyPdfBytes` puis remboursé en cas d'échec.
class JourneyEntitlementsService {
  JourneyEntitlementsService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    SubscriptionConfigService? configService,
    SubscriptionCreditService? creditService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _configService = configService ?? SubscriptionConfigService(),
        _creditService = creditService ?? SubscriptionCreditService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final SubscriptionConfigService _configService;
  final SubscriptionCreditService _creditService;

  Future<JourneyEntitlements> resolveEntitlements() async {
    try {
      final config = await _configService.getConfig();
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        return resolveJourneyEntitlementsForAccess(
          SubscriptionPlan.free,
          freeAccessMode: config.freeAccessMode,
        );
      }

      final snap = await _db.collection('users').doc(uid).get();
      final state = AppUserSubscriptionState.fromMap(snap.data());
      return resolveJourneyEntitlementsForAccess(
        state.plan,
        freeAccessMode: config.freeAccessMode,
      );
    } catch (e) {
      debugPrint(
        '[JourneyEntitlements] resolve failed, defaulting to plan Gratuit: $e',
      );
      return resolveJourneyEntitlementsForAccess(
        SubscriptionPlan.free,
        freeAccessMode: false,
      );
    }
  }

  Future<SubscriptionCreditSnapshot?> _tryLoadCredits() async {
    try {
      return await _creditService.getSnapshot();
    } catch (error) {
      debugPrint('[JourneyEntitlements] credit snapshot unavailable: $error');
      return null;
    }
  }

  /// Conserve le nom historique pour ne pas casser les écrans existants.
  /// La valeur représente maintenant le nombre de parcours présents dans la
  /// bibliothèque cloud, et non un compteur mensuel local.
  Future<int> getLocalSavesUsedThisMonth() async {
    final snapshot = await _tryLoadCredits();
    return snapshot?[SubscriptionCreditKind.journeys].used ?? 0;
  }

  Future<int> getPdfExportsUsedThisMonth() async {
    final snapshot = await _tryLoadCredits();
    return snapshot?[SubscriptionCreditKind.pdf].used ?? 0;
  }

  Future<JourneySaveDecision> evaluateLocalSave() async {
    final entitlements = await resolveEntitlements();
    final snapshot = await _tryLoadCredits();
    final status = snapshot?[SubscriptionCreditKind.journeys];
    final used = status?.used ?? 0;
    return JourneySaveDecision(
      allowed: status == null || status.unlimited || !status.exhausted,
      entitlements: entitlements,
      usedThisMonth: used,
    );
  }

  /// Le débit est effectué dans `JourneyLocalStorageService.saveSnapshot` par
  /// l'opération serveur `saveMyJourney`.
  Future<void> recordLocalSave() async {}

  Future<JourneyPdfExportDecision> evaluatePdfExport() async {
    final entitlements = await resolveEntitlements();
    if (!entitlements.canExportPdf) {
      return JourneyPdfExportDecision(
        allowed: false,
        requiresUpgrade: true,
        entitlements: entitlements,
        usedThisMonth: 0,
      );
    }

    final snapshot = await _tryLoadCredits();
    final status = snapshot?[SubscriptionCreditKind.pdf];
    return JourneyPdfExportDecision(
      allowed: status == null || status.unlimited || !status.exhausted,
      requiresUpgrade: false,
      entitlements: entitlements,
      usedThisMonth: status?.used ?? 0,
    );
  }

  /// Le débit PDF est centralisé dans `saveJourneyPdfBytes`, après génération
  /// du document et avant son téléchargement effectif.
  Future<void> recordPdfExport() async {}
}

class JourneySaveDecision {
  final bool allowed;
  final JourneyEntitlements entitlements;
  final int usedThisMonth;

  const JourneySaveDecision({
    required this.allowed,
    required this.entitlements,
    required this.usedThisMonth,
  });
}

class JourneyPdfExportDecision {
  final bool allowed;
  final bool requiresUpgrade;
  final JourneyEntitlements entitlements;
  final int usedThisMonth;

  const JourneyPdfExportDecision({
    required this.allowed,
    required this.requiresUpgrade,
    required this.entitlements,
    required this.usedThisMonth,
  });
}
