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
  proStatus: 'verified',
);

void main() {
  testWidgets('affiche le chargement puis le résultat et appelle le callback', (
    tester,
  ) async {
    final pending = Completer<ProSiretVerificationResult>();
    ProSiretVerificationResult? callbackResult;
    String? received;

    await tester.pumpWidget(
      _host(
        ProSiretVerificationCard(
          verifier: (value) {
            received = value;
            return pending.future;
          },
          onVerified: (result) => callbackResult = result,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '73282932000074');
    await tester.tap(find.text('Vérifier mon SIRET'));
    await tester.pump();

    expect(find.text('Vérification...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(received, '73282932000074');

    pending.complete(_verified);
    await tester.pumpAndSettle();

    expect(callbackResult, same(_verified));
    expect(find.text('Entreprise trouvée'), findsOneWidget);
    expect(find.textContaining('Entreprise Démo'), findsOneWidget);
    expect(find.textContaining('97122 Baie-Mahault'), findsOneWidget);
    expect(find.textContaining('Activité : 6201Z'), findsOneWidget);
  });

  testWidgets('affiche une erreur puis efface le champ et le message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ProSiretVerificationCard(
          verifier: (_) async => throw Exception('SIRET indisponible'),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '73282932000074');
    await tester.tap(find.text('Vérifier mon SIRET'));
    await tester.pumpAndSettle();

    expect(find.text('SIRET non validé'), findsOneWidget);
    expect(find.text('SIRET indisponible'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    expect(find.text('SIRET non validé'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('soumission clavier utilise le vérificateur injecté', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(
        ProSiretVerificationCard(
          verifier: (_) async {
            calls++;
            return _verified;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '73282932000074');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Entreprise trouvée'), findsOneWidget);
  });
}
