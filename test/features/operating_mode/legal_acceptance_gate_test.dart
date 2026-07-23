import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/operating_mode/app_operating_mode.dart';
import 'package:presto_app/features/operating_mode/legal_acceptance.dart';
import 'package:presto_app/features/operating_mode/legal_acceptance_gate.dart';

const publisher = LegalPublisherProfile(
  publisherName: 'Exploitant Test',
  postalAddress: '1 rue de Test',
  phone: '0590000000',
  email: 'contact@ilipresto.fr',
  publicationDirector: 'Exploitant Test',
  companyName: 'ILIPRESTO',
  legalForm: 'SASU',
  siren: '123456789',
  rcs: 'RCS TEST',
  shareCapital: '1 000 €',
  vatNumber: 'FR00123456789',
  hostingProvider: 'Google Ireland Limited',
  hostingAddress: 'Dublin, Irlande',
);

final commercialState = AppOperatingModeState(
  mode: AppOperatingMode.commercial,
  publisher: publisher,
  legalVersion: 'commercial-v1',
  cguVersion: 'cgu-commercial-v1',
  privacyVersion: 'privacy-commercial-v1',
  effectiveDate: DateTime.utc(2026, 7, 23),
  requiresReacceptance: true,
);

Widget app(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  test('compare toutes les versions juridiques', () {
    final matching = <String, dynamic>{
      'legalAcceptance': <String, dynamic>{
        'operatingMode': 'commercial',
        'legalVersion': 'commercial-v1',
        'cguVersion': 'cgu-commercial-v1',
        'privacyVersion': 'privacy-commercial-v1',
      },
    };
    expect(
      hasAcceptedCurrentLegalDocuments(matching, commercialState),
      isTrue,
    );
    matching['legalAcceptance']['cguVersion'] = 'cgu-beta-free-v1';
    expect(
      hasAcceptedCurrentLegalDocuments(matching, commercialState),
      isFalse,
    );
  });

  testWidgets('masque le contenu payant sans acceptation commerciale',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = AppOperatingModeService(firestore: firestore);
    await firestore.collection('users').doc('user-1').set({
      'legalAcceptance': {
        'operatingMode': 'free_beta',
        'legalVersion': 'beta-free-v1',
        'cguVersion': 'cgu-beta-free-v1',
        'privacyVersion': 'privacy-beta-free-v1',
      },
    });

    await tester.pumpWidget(
      app(
        LegalAcceptanceGate(
          userId: 'user-1',
          state: commercialState,
          firestore: firestore,
          service: service,
          acceptedChild: const Text('OFFRES PAYANTES'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nouvelles conditions à accepter'), findsOneWidget);
    expect(find.text('OFFRES PAYANTES'), findsNothing);
  });

  testWidgets('affiche le contenu après acceptation des versions exactes',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = AppOperatingModeService(firestore: firestore);
    await firestore.collection('users').doc('user-1').set({
      'legalAcceptance': {
        'operatingMode': 'commercial',
        'legalVersion': 'commercial-v1',
        'cguVersion': 'cgu-commercial-v1',
        'privacyVersion': 'privacy-commercial-v1',
      },
    });

    await tester.pumpWidget(
      app(
        LegalAcceptanceGate(
          userId: 'user-1',
          state: commercialState,
          firestore: firestore,
          service: service,
          acceptedChild: const Text('OFFRES PAYANTES'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OFFRES PAYANTES'), findsOneWidget);
    expect(find.text('Nouvelles conditions à accepter'), findsNothing);
  });

  testWidgets('enregistre la nouvelle acceptation avant d’ouvrir les offres',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = AppOperatingModeService(firestore: firestore);
    await firestore.collection('users').doc('user-1').set({});

    await tester.pumpWidget(
      app(
        LegalAcceptanceGate(
          userId: 'user-1',
          state: commercialState,
          firestore: firestore,
          service: service,
          acceptedChild: const Text('OFFRES PAYANTES'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Consulter et accepter'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelles conditions commerciales'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Accepter'));
    await tester.pumpAndSettle();

    final user = await firestore.collection('users').doc('user-1').get();
    final acceptance =
        user.data()!['legalAcceptance'] as Map<String, dynamic>;
    expect(acceptance['operatingMode'], 'commercial');
    expect(acceptance['cguVersion'], 'cgu-commercial-v1');
    expect(acceptance['privacyVersion'], 'privacy-commercial-v1');
    expect(acceptance['source'], 'commercial_reacceptance');
    expect(find.text('OFFRES PAYANTES'), findsOneWidget);
  });
}
