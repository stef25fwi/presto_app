import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../operating_mode/app_operating_mode.dart';
import 'subscription_models.dart';

class SubscriptionConfigService {
  SubscriptionConfigService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.collection('app_config').doc('subscriptions');

  SubscriptionAppConfig _resolveConfig(Map<String, dynamic>? data) {
    final parsed = SubscriptionAppConfig.fromMap(data);
    final mode = appOperatingModeFromValue(data?['operatingMode']);
    if (mode == AppOperatingMode.freeBeta) {
      return parsed.copyWith(
        subscriptionSectionEnabled: false,
        stripeEnabled: false,
        freeAccessMode: true,
      );
    }
    return parsed;
  }

  Stream<SubscriptionAppConfig> watchConfig({bool ensureExists = false}) {
    if (ensureExists) {
      unawaited(ensureDefaultConfigExists());
    }

    return _configRef.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return const SubscriptionAppConfig.defaults();
      }
      return _resolveConfig(snapshot.data());
    });
  }

  Future<SubscriptionAppConfig> getConfig() async {
    final snapshot = await _configRef.get();
    if (!snapshot.exists) {
      return const SubscriptionAppConfig.defaults();
    }
    return _resolveConfig(snapshot.data());
  }

  Future<AppOperatingMode> getOperatingMode() async {
    final snapshot = await _configRef.get();
    return appOperatingModeFromValue(snapshot.data()?['operatingMode']);
  }

  Future<void> ensureDefaultConfigExists({String? updatedBy}) async {
    final snapshot = await _configRef.get();
    if (snapshot.exists && snapshot.data()?['operatingMode'] != null) {
      return;
    }

    const defaults = SubscriptionAppConfig.defaults();
    await _configRef.set(
      <String, dynamic>{
        ...defaults.toFirestoreMap(
          includeServerTimestamp: true,
          nextUpdatedBy: updatedBy,
        ),
        'operatingMode': AppOperatingMode.freeBeta.firestoreValue,
        'legalDocumentVersion': 'beta-free-v1',
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateOperatingMode(
    AppOperatingMode mode, {
    String? updatedBy,
  }) {
    return AppOperatingModeService(firestore: _firestore).setMode(
      mode,
      updatedBy: updatedBy,
    );
  }

  /// Compatibilité avec les anciens contrôles. Le nouveau panneau admin doit
  /// utiliser [updateOperatingMode] afin d'appliquer tous les garde-fous.
  Future<void> updateSectionVisibility(
    bool enabled, {
    String? updatedBy,
  }) async {
    final baseConfig = await getConfig();
    await _configRef.set(
      baseConfig.copyWith(subscriptionSectionEnabled: enabled).toFirestoreMap(
            includeServerTimestamp: true,
            nextUpdatedBy: updatedBy,
          ),
      SetOptions(merge: true),
    );
  }

  Future<void> updateStripeEnabled(
    bool enabled, {
    String? updatedBy,
  }) async {
    if (enabled && await getOperatingMode() == AppOperatingMode.freeBeta) {
      throw StateError(
        'Stripe ne peut pas être activé séparément en mode bêta gratuite.',
      );
    }
    final baseConfig = await getConfig();
    await _configRef.set(
      baseConfig.copyWith(stripeEnabled: enabled).toFirestoreMap(
            includeServerTimestamp: true,
            nextUpdatedBy: updatedBy,
          ),
      SetOptions(merge: true),
    );
  }

  Future<void> updateFreeAccessMode(
    bool enabled, {
    String? updatedBy,
  }) async {
    if (enabled) {
      await updateOperatingMode(AppOperatingMode.freeBeta, updatedBy: updatedBy);
      return;
    }
    await updateOperatingMode(AppOperatingMode.commercial, updatedBy: updatedBy);
  }
}

extension on SubscriptionAppConfig {
  SubscriptionAppConfig copyWith({
    bool? subscriptionSectionEnabled,
    bool? subscriptionsPrepared,
    bool? stripeEnabled,
    bool? freeAccessMode,
    Timestamp? updatedAt,
    String? updatedBy,
  }) {
    return SubscriptionAppConfig(
      subscriptionSectionEnabled:
          subscriptionSectionEnabled ?? this.subscriptionSectionEnabled,
      subscriptionsPrepared:
          subscriptionsPrepared ?? this.subscriptionsPrepared,
      stripeEnabled: stripeEnabled ?? this.stripeEnabled,
      freeAccessMode: freeAccessMode ?? this.freeAccessMode,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
