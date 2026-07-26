import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/operating_mode/app_operating_mode.dart';
import 'package:presto_app/features/operating_mode/legal_acceptance_gate.dart';
import 'package:presto_app/pages/legal_info_page.dart';

const _publisher = LegalPublisherProfile(
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

final _commercialState = AppOperatingModeState(
  mode: AppOperatingMode.commercial,
  publisher: _publisher,
  legalVersion: 'commercial-v1',
  cguVersion: 'cgu-commercial-v1',
  privacyVersion: 'privacy-commercial-v1',
  effectiveDate: DateTime.utc(2026, 7, 23),
  requiresReacceptance: true,
);

class _ControlledOperatingModeService extends AppOperatingModeService {
  _ControlledOperatingModeService({this.failure})
      : super(firestore: FakeFirebaseFirestore());

  final Object? failure;

  @override
  Stream<AppOperatingModeState> watchPublicState() {
    return Stream<AppOperatingModeState>.value(_commercialState);
  }

  @override
  Future<void> recordAcceptance({
    required String userId,
    required AppOperatingModeState state,
    String source = 'registration',
  }) async {
    final error = failure;
    if (error != null) throw error;
  }
}

Widget _app({
  required FakeFirebaseFirestore firestore,
  required AppOperatingModeService service,
}) {
  return MaterialApp(
    home: Scaffold(
      body: LegalAcceptanceGate(
        userId: 'user-1',
        state: _commercialState,
        firestore: firestore,
        service: service,
        acceptedChild: const Text('OFFRES PAYANTES'),
      ),
    ),
  );
}

Future<void> _openAcceptanceDialog(WidgetTester tester) async {
  await tester.tap(find.text('Consulter et accepter'));
  await tester.pumpAndSettle();
  expect(find.text('Nouvelles conditions commerciales'), findsOneWidget);
}

Future<void> _confirmAcceptance(WidgetTester tester) async {
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
  await tester.tap(find.text('Accepter'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ouvre les CGU et la confidentialité puis ferme le dialogue',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('user-1').set(<String, dynamic>{});
    final service = _ControlledOperatingModeService();

    await tester.pumpWidget(_app(firestore: firestore, service: service));
    await tester.pumpAndSettle();
    await _openAcceptanceDialog(tester);

    await tester.tap(find.text('Lire les CGU'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalInfoPage), findsOneWidget);
    expect(find.text('CGU'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Nouvelles conditions commerciales'), findsOneWidget);

    await tester.tap(find.text('Lire la confidentialité'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalInfoPage), findsOneWidget);
    expect(find.text('Confidentialité'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelles conditions commerciales'), findsNothing);
  });

  testWidgets('affiche la confirmation lorsque l enregistrement réussit',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('user-1').set(<String, dynamic>{});
    final service = _ControlledOperatingModeService();

    await tester.pumpWidget(_app(firestore: firestore, service: service));
    await tester.pumpAndSettle();
    await _openAcceptanceDialog(tester);
    await _confirmAcceptance(tester);

    expect(find.text('Nouvelles conditions acceptées.'), findsOneWidget);
    expect(find.text('Nouvelles conditions à accepter'), findsOneWidget);
  });

  testWidgets('affiche l erreur lorsque l enregistrement échoue',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('user-1').set(<String, dynamic>{});
    final service = _ControlledOperatingModeService(
      failure: StateError('échec contrôlé'),
    );

    await tester.pumpWidget(_app(firestore: firestore, service: service));
    await tester.pumpAndSettle();
    await _openAcceptanceDialog(tester);
    await _confirmAcceptance(tester);

    expect(
      find.text(
        'Impossible d’enregistrer l’acceptation. Réessayez avant de souscrire.',
      ),
      findsOneWidget,
    );
    expect(find.text('Nouvelles conditions à accepter'), findsOneWidget);
  });
}
