import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_config_service.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late SubscriptionConfigService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = SubscriptionConfigService(firestore: firestore);
  });

  test('getConfig retourne les valeurs par défaut sans document', () async {
    final config = await service.getConfig();
    expect(config.subscriptionSectionEnabled, isFalse);
    expect(config.subscriptionsPrepared, isTrue);
    expect(config.stripeEnabled, isFalse);
    expect(config.freeAccessMode, isTrue);
  });

  test('watchConfig retourne les valeurs par défaut sans document', () async {
    final config = await service.watchConfig().first;
    expect(config, isA<SubscriptionAppConfig>());
    expect(config.freeAccessMode, isTrue);
  });

  test('ensureDefaultConfigExists crée une seule configuration', () async {
    await service.ensureDefaultConfigExists(updatedBy: 'admin-1');
    final snapshot =
        await firestore.collection('app_config').doc('subscriptions').get();
    expect(snapshot.exists, isTrue);
    expect(snapshot.data()!['updatedBy'], 'admin-1');

    await firestore.collection('app_config').doc('subscriptions').update({
      'stripeEnabled': true,
    });
    await service.ensureDefaultConfigExists(updatedBy: 'admin-2');
    final preserved =
        await firestore.collection('app_config').doc('subscriptions').get();
    expect(preserved.data()!['stripeEnabled'], isTrue);
    expect(preserved.data()!['updatedBy'], 'admin-1');
  });

  test('watchConfig ensureExists initialise puis émet la configuration',
      () async {
    final stream = service.watchConfig(ensureExists: true);
    final config = await stream.firstWhere(
      (value) => value.subscriptionsPrepared,
    );
    expect(config.subscriptionSectionEnabled, isFalse);

    await Future<void>.delayed(Duration.zero);
    final snapshot =
        await firestore.collection('app_config').doc('subscriptions').get();
    expect(snapshot.exists, isTrue);
  });

  test('getConfig et watchConfig lisent une configuration existante', () async {
    await firestore.collection('app_config').doc('subscriptions').set({
      'subscriptionSectionEnabled': false,
      'subscriptionsPrepared': true,
      'stripeEnabled': true,
      'freeAccessMode': false,
      'updatedBy': 'admin',
    });

    final fetched = await service.getConfig();
    final watched = await service.watchConfig().first;
    expect(fetched.subscriptionSectionEnabled, isFalse);
    expect(fetched.stripeEnabled, isTrue);
    expect(fetched.freeAccessMode, isFalse);
    expect(watched.updatedBy, 'admin');
  });

  test('updateSectionVisibility conserve les autres paramètres', () async {
    await service.ensureDefaultConfigExists();
    await service.updateSectionVisibility(false, updatedBy: 'visibility-admin');

    final config = await service.getConfig();
    expect(config.subscriptionSectionEnabled, isFalse);
    expect(config.subscriptionsPrepared, isTrue);
    expect(config.stripeEnabled, isFalse);
    expect(config.freeAccessMode, isTrue);
    expect(config.updatedBy, 'visibility-admin');
  });

  test('updateStripeEnabled conserve les autres paramètres', () async {
    await service.ensureDefaultConfigExists();
    await service.updateStripeEnabled(true, updatedBy: 'stripe-admin');

    final config = await service.getConfig();
    expect(config.subscriptionSectionEnabled, isFalse);
    expect(config.stripeEnabled, isTrue);
    expect(config.freeAccessMode, isTrue);
    expect(config.updatedBy, 'stripe-admin');
  });

  test('updateFreeAccessMode conserve les autres paramètres', () async {
    await service.ensureDefaultConfigExists();
    await service.updateFreeAccessMode(false, updatedBy: 'access-admin');

    final config = await service.getConfig();
    expect(config.subscriptionSectionEnabled, isFalse);
    expect(config.stripeEnabled, isFalse);
    expect(config.freeAccessMode, isFalse);
    expect(config.updatedBy, 'access-admin');
  });

  test('les mises à jour partent aussi de la configuration par défaut', () async {
    await service.updateStripeEnabled(true);
    await service.updateSectionVisibility(false);
    await service.updateFreeAccessMode(false);

    final config = await service.getConfig();
    expect(config.stripeEnabled, isTrue);
    expect(config.subscriptionSectionEnabled, isFalse);
    expect(config.freeAccessMode, isFalse);
  });
}
