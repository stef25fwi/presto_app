import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/operating_mode/app_operating_mode.dart';
import 'package:presto_app/features/subscriptions/subscription_config_service.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

const completePublisher = <String, dynamic>{
  'publisherName': 'Exploitant Test',
  'postalAddress': '1 rue de Test',
  'phone': '0590000000',
  'email': 'contact@ilipresto.fr',
  'publicationDirector': 'Exploitant Test',
  'companyName': 'ILIPRESTO',
  'legalForm': 'SASU',
  'siren': '123456789',
  'hostingProvider': 'Google Ireland Limited',
  'hostingAddress': 'Dublin, Irlande',
};

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

  test('ensureDefaultConfigExists crée une configuration bêta sûre', () async {
    await service.ensureDefaultConfigExists(updatedBy: 'admin-1');
    final snapshot =
        await firestore.collection('app_config').doc('subscriptions').get();
    expect(snapshot.exists, isTrue);
    expect(snapshot.data()!['operatingMode'], 'free_beta');
    expect(snapshot.data()!['stripeEnabled'], isFalse);
    expect(snapshot.data()!['freeAccessMode'], isTrue);
    expect(snapshot.data()!['updatedBy'], 'admin-1');
  });

  test('la bêta neutralise une ancienne configuration Stripe incohérente',
      () async {
    await firestore.collection('app_config').doc('subscriptions').set({
      'operatingMode': 'free_beta',
      'subscriptionSectionEnabled': true,
      'subscriptionsPrepared': true,
      'stripeEnabled': true,
      'freeAccessMode': false,
      'updatedBy': 'legacy-admin',
    });

    final fetched = await service.getConfig();
    final watched = await service.watchConfig().first;
    expect(fetched.subscriptionSectionEnabled, isFalse);
    expect(fetched.stripeEnabled, isFalse);
    expect(fetched.freeAccessMode, isTrue);
    expect(watched.updatedBy, 'legacy-admin');
  });

  test('une configuration commerciale conserve les champs payants', () async {
    await firestore.collection('app_config').doc('subscriptions').set({
      'operatingMode': 'commercial',
      'subscriptionSectionEnabled': true,
      'subscriptionsPrepared': true,
      'stripeEnabled': true,
      'freeAccessMode': false,
      'updatedBy': 'commercial-admin',
    });

    final config = await service.getConfig();
    expect(config.subscriptionSectionEnabled, isTrue);
    expect(config.stripeEnabled, isTrue);
    expect(config.freeAccessMode, isFalse);
  });

  test('Stripe ne peut pas être activé isolément pendant la bêta', () async {
    await service.ensureDefaultConfigExists();
    expect(
      () => service.updateStripeEnabled(true),
      throwsStateError,
    );
  });

  test('updateFreeAccessMode true conserve la bêta gratuite', () async {
    final modeService = AppOperatingModeService(firestore: firestore);
    await modeService.ensureDefaults();
    await modeService.updatePublisherProfile(
      LegalPublisherProfile.fromMap(completePublisher),
    );

    await service.updateFreeAccessMode(true, updatedBy: 'access-admin');
    final config = await service.getConfig();
    expect(config.subscriptionSectionEnabled, isFalse);
    expect(config.stripeEnabled, isFalse);
    expect(config.freeAccessMode, isTrue);
  });

  test('la bascule commerciale passe par le profil juridique complet', () async {
    final modeService = AppOperatingModeService(firestore: firestore);
    await modeService.ensureDefaults();
    await modeService.updatePublisherProfile(
      LegalPublisherProfile.fromMap(completePublisher),
    );

    await service.updateOperatingMode(
      AppOperatingMode.commercial,
      updatedBy: 'commercial-admin',
    );
    final config = await service.getConfig();
    expect(config.subscriptionSectionEnabled, isTrue);
    expect(config.stripeEnabled, isTrue);
    expect(config.freeAccessMode, isFalse);
  });
}
