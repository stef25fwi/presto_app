import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'subscription_config_service.dart';
import 'subscription_models.dart';

/// Suit le quota mensuel "1 assistance IA pour rédiger une annonce" du plan
/// Gratuit. Suit le même schéma local (SharedPreferences, période
/// `yyyy-MM`) que [JourneyEntitlementsService] — cohérent avec l'existant,
/// mais non synchronisé multi-appareils : cette fonctionnalité vise à faire
/// tester l'IA une fois, pas à sécuriser un accès payant.
class AiDraftQuotaService {
  AiDraftQuotaService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    SubscriptionConfigService? configService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _configService = configService ?? SubscriptionConfigService();

  static const _kCountKey = 'toolbox.ai_draft_quota.count';
  static const _kPeriodKey = 'toolbox.ai_draft_quota.period';

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final SubscriptionConfigService _configService;

  String _currentPeriodKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<SubscriptionFeatures> _resolveFeatures() async {
    try {
      final config = await _configService.getConfig();
      if (config.freeAccessMode) {
        return getFeaturesForSubscriptionPlan(
          SubscriptionPlan.free,
          freeAccessMode: true,
        );
      }

      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        return getFeaturesForSubscriptionPlan(
          SubscriptionPlan.free,
          freeAccessMode: false,
        );
      }

      final snap = await _db.collection('users').doc(uid).get();
      final state = AppUserSubscriptionState.fromMap(snap.data());
      return getFeaturesForSubscriptionPlan(state.plan, freeAccessMode: false);
    } catch (e) {
      debugPrint(
        '[AiDraftQuota] resolve failed, defaulting to plan Gratuit: $e',
      );
      return getFeaturesForSubscriptionPlan(
        SubscriptionPlan.free,
        freeAccessMode: false,
      );
    }
  }

  Future<int> getUsedThisMonth() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPeriod = prefs.getString(_kPeriodKey);
    if (storedPeriod != _currentPeriodKey()) {
      return 0;
    }
    return prefs.getInt(_kCountKey) ?? 0;
  }

  /// À appeler avant de lancer une génération IA d'annonce.
  Future<AiDraftQuotaDecision> evaluate() async {
    final features = await _resolveFeatures();
    final used = await getUsedThisMonth();
    return AiDraftQuotaDecision(
      allowed: used < features.maxMonthlyAiAdDrafts,
      maxPerMonth: features.maxMonthlyAiAdDrafts,
      usedThisMonth: used,
    );
  }

  /// À appeler après une génération IA réussie.
  Future<void> recordUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final period = _currentPeriodKey();
    final used = await getUsedThisMonth();
    await prefs.setString(_kPeriodKey, period);
    await prefs.setInt(_kCountKey, used + 1);
  }
}

class AiDraftQuotaDecision {
  final bool allowed;
  final int maxPerMonth;
  final int usedThisMonth;

  const AiDraftQuotaDecision({
    required this.allowed,
    required this.maxPerMonth,
    required this.usedThisMonth,
  });
}
