import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'subscription_config_service.dart';
import 'subscription_models.dart';

/// Résout les droits (entitlements) de l'utilisateur courant pour "Mon
/// parcours personnalisé" et suit ses quotas mensuels de sauvegarde locale
/// et d'export PDF.
///
/// Le compteur est stocké en local (SharedPreferences), car la sauvegarde du
/// parcours elle-même est locale à l'appareil (voir
/// `JourneyLocalStorageService`) : il n'y a donc pas de synchronisation
/// multi-appareils du quota, ce qui est cohérent avec la fonctionnalité.
class JourneyEntitlementsService {
  JourneyEntitlementsService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    SubscriptionConfigService? configService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _configService = configService ?? SubscriptionConfigService();

  static const _kSavesCountKey = 'toolbox.journey_quota.saves_count';
  static const _kSavesPeriodKey = 'toolbox.journey_quota.saves_period';
  static const _kPdfCountKey = 'toolbox.journey_quota.pdf_count';
  static const _kPdfPeriodKey = 'toolbox.journey_quota.pdf_period';

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final SubscriptionConfigService _configService;

  String _currentPeriodKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Détermine les droits applicables au parcours personnalisé pour
  /// l'utilisateur courant (plan d'abonnement + mode d'accès libre global).
  ///
  /// Même lorsque le mode d'accès gratuit complet est actif, on lit le vrai
  /// plan utilisateur afin que les quotas PDF restent cohérents :
  /// - Gratuit : aucun PDF ;
  /// - ilipresto+ : 2 PDF/mois ;
  /// - ilipro : 10 PDF/mois.
  Future<JourneyEntitlements> resolveEntitlements() async {
    try {
      final config = await _configService.getConfig();
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        return getJourneyEntitlementsForPlan(
          SubscriptionPlan.free,
          freeAccessMode: config.freeAccessMode,
        );
      }

      final snap = await _db.collection('users').doc(uid).get();
      final state = AppUserSubscriptionState.fromMap(snap.data());
      return getJourneyEntitlementsForPlan(
        state.plan,
        freeAccessMode: config.freeAccessMode,
      );
    } catch (e) {
      debugPrint(
        '[JourneyEntitlements] resolve failed, defaulting to plan Gratuit: $e',
      );
      return getJourneyEntitlementsForPlan(
        SubscriptionPlan.free,
        freeAccessMode: false,
      );
    }
  }

  int _readCount(SharedPreferences prefs, String countKey, String periodKey) {
    final storedPeriod = prefs.getString(periodKey);
    if (storedPeriod != _currentPeriodKey()) {
      return 0;
    }
    return prefs.getInt(countKey) ?? 0;
  }

  Future<void> _increment(
    SharedPreferences prefs,
    String countKey,
    String periodKey,
  ) async {
    final period = _currentPeriodKey();
    final current = _readCount(prefs, countKey, periodKey);
    await prefs.setString(periodKey, period);
    await prefs.setInt(countKey, current + 1);
  }

  Future<int> getLocalSavesUsedThisMonth() async {
    final prefs = await SharedPreferences.getInstance();
    return _readCount(prefs, _kSavesCountKey, _kSavesPeriodKey);
  }

  Future<int> getPdfExportsUsedThisMonth() async {
    final prefs = await SharedPreferences.getInstance();
    return _readCount(prefs, _kPdfCountKey, _kPdfPeriodKey);
  }

  /// À appeler avant d'autoriser une sauvegarde locale du parcours.
  Future<JourneySaveDecision> evaluateLocalSave() async {
    final entitlements = await resolveEntitlements();
    final used = await getLocalSavesUsedThisMonth();
    return JourneySaveDecision(
      allowed: used < entitlements.maxLocalSavesPerMonth,
      entitlements: entitlements,
      usedThisMonth: used,
    );
  }

  Future<void> recordLocalSave() async {
    final prefs = await SharedPreferences.getInstance();
    await _increment(prefs, _kSavesCountKey, _kSavesPeriodKey);
  }

  /// À appeler avant d'autoriser un export PDF du parcours.
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

    final used = await getPdfExportsUsedThisMonth();
    return JourneyPdfExportDecision(
      allowed: used < entitlements.maxPdfExportsPerMonth,
      requiresUpgrade: false,
      entitlements: entitlements,
      usedThisMonth: used,
    );
  }

  Future<void> recordPdfExport() async {
    final prefs = await SharedPreferences.getInstance();
    await _increment(prefs, _kPdfCountKey, _kPdfPeriodKey);
  }
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
