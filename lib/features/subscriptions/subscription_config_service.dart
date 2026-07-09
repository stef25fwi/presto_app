import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'subscription_models.dart';

class SubscriptionConfigService {
  SubscriptionConfigService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.collection('app_config').doc('subscriptions');

  Stream<SubscriptionAppConfig> watchConfig({bool ensureExists = false}) {
    if (ensureExists) {
      unawaited(ensureDefaultConfigExists());
    }

    return _configRef.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return const SubscriptionAppConfig.defaults();
      }
      return SubscriptionAppConfig.fromMap(snapshot.data());
    });
  }

  Future<SubscriptionAppConfig> getConfig() async {
    final snapshot = await _configRef.get();
    if (!snapshot.exists) {
      return const SubscriptionAppConfig.defaults();
    }
    return SubscriptionAppConfig.fromMap(snapshot.data());
  }

  Future<void> ensureDefaultConfigExists({String? updatedBy}) async {
    final snapshot = await _configRef.get();
    if (snapshot.exists) {
      return;
    }

    const defaults = SubscriptionAppConfig.defaults();
    await _configRef.set(
      defaults.toFirestoreMap(
        includeServerTimestamp: true,
        nextUpdatedBy: updatedBy,
      ),
      SetOptions(merge: true),
    );
  }

  Future<void> updateSectionVisibility(
    bool enabled, {
    String? updatedBy,
  }) async {
    final currentConfig = await getConfig();

    await _configRef.set(
      currentConfig
          .copyWith(subscriptionSectionEnabled: enabled)
          .toFirestoreMap(
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
    final currentConfig = await getConfig();

    await _configRef.set(
      currentConfig.copyWith(freeAccessMode: enabled).toFirestoreMap(
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
    final currentConfig = await getConfig();

    await _configRef.set(
      currentConfig.copyWith(stripeEnabled: enabled).toFirestoreMap(
            includeServerTimestamp: true,
            nextUpdatedBy: updatedBy,
          ),
      SetOptions(merge: true),
    );
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
