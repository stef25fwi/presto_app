import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/pro_siret_service.dart';
import 'package:presto_app/widgets/pro_siret_verification_card.dart';

Widget _host(ProSiretVerificationCard card) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: card),
    ),
  );
}

const _verified = ProSiretVerificationResult(
  ok: true,
  siret: '73282932000074',
  siren: '732829320',
  companyName: 'Entreprise Démo',
  address: '1 rue du Test',
  postalCode: '97122',
  city: 'Baie-Mahault',
  nafCode: '6201Z',
  proStatus: 'verified_siret_leader_match',
  leaderDeclaredMatch: true,
  declaredLeaderFirstName: 'Marie',
  declaredLeaderLastName: 'Dupont',
  declaredLeaderRole: 'Gérante',
  verificationLevel: 'siret_declared_leader_match',
);

Future<void> _fillVerificationFields(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  expect(fields, findsNWidgets(3));
  await tester.enterText(fields.at(0), '73282932000074');
  await tester.enterText(fields.at(1), 'Marie');
  await tester.enterText(fields.at(2), 'Dupont');
}

void main() {
  testWidgets('transmet SIRET et dirigeant puis affiche la concordance', (
    tester,
  ) async {
    final pending = Completer<ProSiretVerificationResult>();
    ProSiretVerificationResult? callbackResult;
    String? receivedSiret;
    String? receivedFirstName;
    String? receivedLastName;

    await tester.pumpWidget(
      _host(
        ProSiretVerificationCard(
          verifier: (siret, firstName, lastName) {
            receivedSiret = siret;
            receivedFirstName = firstName;
            receivedLastName = lastName;
            return pending.future;
          },
          onVerified: (result) => callbackResult = result,
        ),
      ),
    );

    await _fillVerificationFields(tester);
    await tester.tap(find.text('Vérifier SIRET + dirigeant'));
    await tester.pump();

    expect(find.text('Vérification...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(receivedSiret, '73282932000074');
    expect(receivedFirstName, 'Marie');
    expect(receivedLastName, 'Dupont');

    pending.complete(_verified);
    await tester.pumpAndSettle();

    expect(callbackResult, same(_verified));
    expect(find.text('SIRET + dirigeant concordants'), findsOneWidget);
    expect(find.textContaining('Entreprise Démo'), findsOneWidget);
    expect(find.textContaining('Dirigeant déclaré : Marie Dupont'), findsOneWidget);
    expect(find.textContaining('Qualité : Gérante'), findsOneWidget);
    expect(find.textContaining('97122 Baie-Mahault'), findsOneWidget);
  });

  testWidgets('refuse la vérification si le dirigeant est incomplet', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(
        ProSiretVerificationCard(
          verifier: (_, __, ___) async {
            calls++;
            return _verified;
          },
        ),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '73282932000074');
    await tester.enterText(fields.at(1), 'Marie');
    await tester.tap(find.text('Vérifier SIRET + dirigeant'));
    await tester.pump();

    expect(calls, 0);
    expect(find.text('Nom obligatoire.'), findsOneWidget);
  });

  testWidgets('affiche une erreur de concordance', (tester) async {
    await tester.pumpWidget(
      _host(
        ProSiretVerificationCard(
          verifier: (_, __, ___) async =>
              throw Exception('Le dirigeant déclaré ne concorde pas'),
        ),
      ),
    );

    await _fillVerificationFields(tester);
    await tester.tap(find.text('Vérifier SIRET + dirigeant'));
    await tester.pumpAndSettle();

    expect(find.text('Vérification non validée'), findsOneWidget);
    expect(find.text('Le dirigeant déclaré ne concorde pas'), findsOneWidget);
  });
}
