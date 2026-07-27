import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/account/verifier_siret_page.dart';
import 'package:presto_app/widgets/pro_siret_verification_card.dart';

void main() {
  testWidgets('construit la page de vérification SIRET', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: VerifierSiretPage()),
    );

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Vérifier mon SIRET'), findsNWidgets(2));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(ProSiretVerificationCard), findsOneWidget);
  });
}
