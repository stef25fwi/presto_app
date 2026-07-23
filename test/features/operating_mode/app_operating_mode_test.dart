import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/operating_mode/app_operating_mode.dart';

LegalPublisherProfile completeProfile() => const LegalPublisherProfile(
      publisherName: 'Exploitant Test',
      postalAddress: '1 rue de Test, 97122 Baie-Mahault',
      phone: '0590000000',
      email: 'contact@ilipresto.fr',
      publicationDirector: 'Exploitant Test',
      companyName: 'ILIPRESTO',
      legalForm: 'SASU',
      siren: '123456789',
      rcs: 'Pointe-à-Pitre B 123 456 789',
      shareCapital: '1 000 €',
      vatNumber: 'FR00123456789',
      hostingProvider: 'Google Ireland Limited (Firebase Hosting)',
      hostingAddress: 'Gordon House, Dublin 4, Irlande',
    );

void main() {
  test('les valeurs par défaut utilisent la bêta gratuite', () {
    final state = AppOperatingModeState.defaults();
    expect(state.mode, AppOperatingMode.freeBeta);
    expect(state.legalVersion, 'beta-free-v1');
    expect(state.cguVersion, 'cgu-beta-free-v1');
    expect(state.privacyVersion, 'privacy-beta-free-v1');
  });

  test('la complétude dépend du mode demandé', () {
    const incomplete = LegalPublisherProfile.defaults();
    expect(incomplete.isFreeBetaReady, isFalse);
    expect(incomplete.isCommercialReady, isFalse);

    final complete = completeProfile();
    expect(complete.isFreeBetaReady, isTrue);
    expect(complete.isCommercialReady, isTrue);
  });

  test('ensureDefaults crée une configuration bêta fail-closed', () async {
    final firestore = FakeFirebaseFirestore();
    final service = AppOperatingModeService(firestore: firestore);

    await service.ensureDefaults(updatedBy: 'admin-1');

    final legal = await firestore.collection('app_config').doc('legal').get();
    final subscriptions =
        await firestore.collection('app_config').doc('subscriptions').get();

    expect(legal.data()!['operatingMode'], 'free_beta');
    expect(legal.data()!['legalVersion'], 'beta-free-v1');
    expect(subscriptions.data()!['subscriptionSectionEnabled'], isFalse);
    expect(subscriptions.data()!['stripeEnabled'], isFalse);
    expect(subscriptions.data()!['freeAccessMode'], isTrue);
  });

  test('la configuration publique est chargeable sans Firestore client',
      () async {
    final service = AppOperatingModeService(
      firestore: FakeFirebaseFirestore(),
      publicStateLoader: () async => <String, dynamic>{
        'operatingMode': 'free_beta',
        'legalVersion': 'beta-free-v2',
        'cguVersion': 'cgu-beta-free-v2',
        'privacyVersion': 'privacy-beta-free-v2',
        'effectiveDate': '2026-07-23T00:00:00.000Z',
        'requiresReacceptance': false,
        'publisher': completeProfile().toMap(),
      },
    );

    final state = await service.getPublicState();

    expect(state.mode, AppOperatingMode.freeBeta);
    expect(state.legalVersion, 'beta-free-v2');
    expect(state.publisher.publisherName, 'Exploitant Test');
    expect(state.publisher.phone, '0590000000');
    expect(state.publisher.email, 'contact@ilipresto.fr');
    expect(state.isPublicReady, isTrue);
  });

  test('le mode commercial est bloqué sans identité juridique complète',
      () async {
    final service = AppOperatingModeService(
      firestore: FakeFirebaseFirestore(),
    );
    await service.ensureDefaults();

    expect(
      () => service.setMode(AppOperatingMode.commercial),
      throwsStateError,
    );
  });

  test('une bascule commerciale atomique active les champs payants', () async {
    final firestore = FakeFirebaseFirestore();
    final service = AppOperatingModeService(firestore: firestore);
    await service.ensureDefaults();
    await service.updatePublisherProfile(completeProfile());

    await service.setMode(
      AppOperatingMode.commercial,
      updatedBy: 'admin-commercial',
    );

    final legal = await firestore.collection('app_config').doc('legal').get();
    final subscriptions =
        await firestore.collection('app_config').doc('subscriptions').get();
    final history = await firestore.collection('legal_mode_history').get();

    expect(legal.data()!['operatingMode'], 'commercial');
    expect(legal.data()!['legalVersion'], 'commercial-v1');
    expect(legal.data()!['requiresReacceptance'], isTrue);
    expect(subscriptions.data()!['subscriptionSectionEnabled'], isTrue);
    expect(subscriptions.data()!['stripeEnabled'], isTrue);
    expect(subscriptions.data()!['freeAccessMode'], isFalse);
    expect(history.docs, hasLength(1));
  });

  test('le retour en bêta désactive tous les leviers commerciaux', () async {
    final firestore = FakeFirebaseFirestore();
    final service = AppOperatingModeService(firestore: firestore);
    await service.ensureDefaults();
    await service.updatePublisherProfile(completeProfile());
    await service.setMode(AppOperatingMode.commercial);
    await service.setMode(AppOperatingMode.freeBeta);

    final subscriptions =
        await firestore.collection('app_config').doc('subscriptions').get();
    expect(subscriptions.data()!['operatingMode'], 'free_beta');
    expect(subscriptions.data()!['subscriptionSectionEnabled'], isFalse);
    expect(subscriptions.data()!['stripeEnabled'], isFalse);
    expect(subscriptions.data()!['freeAccessMode'], isTrue);
  });

  test('la preuve d’acceptation enregistre les versions exactes', () async {
    final firestore = FakeFirebaseFirestore();
    final service = AppOperatingModeService(firestore: firestore);
    final state = AppOperatingModeState(
      mode: AppOperatingMode.freeBeta,
      publisher: completeProfile(),
      legalVersion: 'beta-free-v1',
      cguVersion: 'cgu-beta-free-v1',
      privacyVersion: 'privacy-beta-free-v1',
      effectiveDate: DateTime.utc(2026, 7, 23),
      requiresReacceptance: false,
    );

    await service.recordAcceptance(userId: 'user-1', state: state);
    final user = await firestore.collection('users').doc('user-1').get();
    final acceptance =
        user.data()!['legalAcceptance'] as Map<String, dynamic>;
    expect(acceptance['operatingMode'], 'free_beta');
    expect(acceptance['cguVersion'], 'cgu-beta-free-v1');
    expect(acceptance['privacyVersion'], 'privacy-beta-free-v1');
  });
}
