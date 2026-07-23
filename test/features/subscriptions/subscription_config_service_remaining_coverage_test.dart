import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/operating_mode/app_operating_mode.dart';
import 'package:presto_app/features/subscriptions/subscription_config_service.dart';

void main() {
  test('watchConfig initialise et expose les valeurs bêta par défaut', () async {
    final firestore = FakeFirebaseFirestore();
    final service = SubscriptionConfigService(firestore: firestore);

    final config = await service.watchConfig(ensureExists: true).first;

    expect(config.subscriptionSectionEnabled, isFalse);
    expect(config.subscriptionsPrepared, isTrue);
    expect(config.stripeEnabled, isFalse);
    expect(config.freeAccessMode, isTrue);

    for (var attempt = 0; attempt < 10; attempt += 1) {
      final snapshot =
          await firestore.collection('app_config').doc('subscriptions').get();
      if (snapshot.exists) break;
      await Future<void>.delayed(Duration.zero);
    }
    final stored =
        await firestore.collection('app_config').doc('subscriptions').get();
    expect(stored.data()?['operatingMode'], 'free_beta');
  });

  test('met à jour la visibilité en préservant le reste de la configuration',
      () async {
    final firestore = FakeFirebaseFirestore();
    final ref = firestore.collection('app_config').doc('subscriptions');
    await ref.set(<String, dynamic>{
      'operatingMode': 'commercial',
      'subscriptionSectionEnabled': false,
      'subscriptionsPrepared': false,
      'stripeEnabled': true,
      'freeAccessMode': false,
      'updatedBy': 'initial',
    });
    final service = SubscriptionConfigService(firestore: firestore);

    await service.updateSectionVisibility(true, updatedBy: 'coverage-worker');

    final data = (await ref.get()).data()!;
    expect(data['subscriptionSectionEnabled'], isTrue);
    expect(data['subscriptionsPrepared'], isFalse);
    expect(data['stripeEnabled'], isTrue);
    expect(data['freeAccessMode'], isFalse);
    expect(data['updatedBy'], 'coverage-worker');
  });

  test('refuse Stripe en bêta puis l active en mode commercial', () async {
    final firestore = FakeFirebaseFirestore();
    final ref = firestore.collection('app_config').doc('subscriptions');
    final service = SubscriptionConfigService(firestore: firestore);

    await ref.set(<String, dynamic>{
      'operatingMode': 'free_beta',
      'subscriptionSectionEnabled': false,
      'subscriptionsPrepared': true,
      'stripeEnabled': false,
      'freeAccessMode': true,
    });
    await expectLater(
      service.updateStripeEnabled(true),
      throwsA(isA<StateError>()),
    );

    await ref.set(<String, dynamic>{
      'operatingMode': 'commercial',
      'subscriptionSectionEnabled': true,
      'subscriptionsPrepared': false,
      'stripeEnabled': false,
      'freeAccessMode': false,
    });
    await service.updateStripeEnabled(true, updatedBy: 'stripe-admin');

    final data = (await ref.get()).data()!;
    expect(data['subscriptionSectionEnabled'], isTrue);
    expect(data['subscriptionsPrepared'], isFalse);
    expect(data['stripeEnabled'], isTrue);
    expect(data['freeAccessMode'], isFalse);
    expect(data['updatedBy'], 'stripe-admin');
  });

  test('bascule entre modes commercial et bêta avec un profil juridique prêt',
      () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('app_config').doc('legal').set(
      <String, dynamic>{
        'operatingMode': 'free_beta',
        'legalVersion': 'beta-free-v1',
        'cguVersion': 'cgu-beta-free-v1',
        'privacyVersion': 'privacy-beta-free-v1',
        'publisher': <String, dynamic>{
          'publisherName': 'Éditeur test',
          'postalAddress': '1 rue du Test',
          'phone': '0590000000',
          'email': 'contact@example.fr',
          'publicationDirector': 'Directeur test',
          'companyName': 'Société test',
          'legalForm': 'SASU',
          'siren': '123456789',
        },
      },
    );
    await firestore.collection('app_config').doc('subscriptions').set(
      <String, dynamic>{
        'operatingMode': 'free_beta',
        'subscriptionSectionEnabled': false,
        'subscriptionsPrepared': true,
        'stripeEnabled': false,
        'freeAccessMode': true,
      },
    );
    final service = SubscriptionConfigService(firestore: firestore);

    await service.updateFreeAccessMode(false, updatedBy: 'commercial-admin');
    expect(await service.getOperatingMode(), AppOperatingMode.commercial);
    var data = (await firestore
            .collection('app_config')
            .doc('subscriptions')
            .get())
        .data()!;
    expect(data['subscriptionSectionEnabled'], isTrue);
    expect(data['stripeEnabled'], isTrue);
    expect(data['freeAccessMode'], isFalse);

    await service.updateFreeAccessMode(true, updatedBy: 'beta-admin');
    expect(await service.getOperatingMode(), AppOperatingMode.freeBeta);
    data = (await firestore.collection('app_config').doc('subscriptions').get())
        .data()!;
    expect(data['subscriptionSectionEnabled'], isFalse);
    expect(data['stripeEnabled'], isFalse);
    expect(data['freeAccessMode'], isTrue);
  });
}
