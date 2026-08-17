import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/pro_siret_service.dart';
import 'package:presto_app/widgets/pro_siret_signup_section.dart';

const _verifiedSiret = '73282932000074';

ProSiretVerificationResult _result({
  String companyName = 'IliPresto Services',
  String city = 'Les Abymes',
}) {
  return ProSiretVerificationResult(
    ok: true,
    siret: _verifiedSiret,
    siren: '732829320',
    companyName: companyName,
    address: '1 rue des Tests',
    postalCode: '97139',
    city: city,
    nafCode: '6201Z',
    proStatus: 'verified',
  );
}

void main() {
  Future<void> pumpSection(
    WidgetTester tester, {
    bool visible = true,
    ProSiretPreVerifier? preVerifier,
    ValueChanged<String>? onSiretChanged,
    ValueChanged<ProSiretVerificationResult>? onVerified,
  }) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ProSiretSignupSection(
              visible: visible,
              preVerifier: preVerifier,
              onSiretChanged: onSiretChanged,
              onVerified: onVerified,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('reste entièrement masquée lorsque visible vaut false',
      (tester) async {
    await pumpSection(tester, visible: false);

    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Vérifier mon SIRET'), findsNothing);
  });

  testWidgets('filtre la saisie aux quatorze chiffres et notifie le parent',
      (tester) async {
    String? changed;
    await pumpSection(
      tester,
      onSiretChanged: (value) => changed = value,
      preVerifier: (_) async => _result(),
    );

    await tester.enterText(
      find.byType(TextFormField),
      '73a282932000074999',
    );
    await tester.pump();

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, _verifiedSiret);
    expect(changed, _verifiedSiret);
  });

  testWidgets('désactive le bouton pendant la vérification puis affiche le succès',
      (tester) async {
    final completer = Completer<ProSiretVerificationResult>();
    String? requestedSiret;
    ProSiretVerificationResult? verified;
    var calls = 0;

    await pumpSection(
      tester,
      preVerifier: (rawSiret) {
        calls += 1;
        requestedSiret = rawSiret;
        return completer.future;
      },
      onVerified: (result) => verified = result,
    );
    await tester.enterText(find.byType(TextFormField), _verifiedSiret);

    await tester.tap(find.text('Vérifier mon SIRET'));
    await tester.pump();

    expect(find.text('Vérification du SIRET...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    expect(calls, 1);

    final success = _result();
    completer.complete(success);
    await tester.pumpAndSettle();

    expect(requestedSiret, _verifiedSiret);
    expect(verified, same(success));
    expect(
      find.text('SIRET vérifié · IliPresto Services · Les Abymes'),
      findsOneWidget,
    );
    expect(find.text('Vérifier mon SIRET'), findsOneWidget);
  });

  testWidgets('affiche un succès minimal sans société ni ville', (tester) async {
    await pumpSection(
      tester,
      preVerifier: (_) async => _result(companyName: '', city: ''),
    );
    await tester.enterText(find.byType(TextFormField), _verifiedSiret);

    await tester.tap(find.text('Vérifier mon SIRET'));
    await tester.pumpAndSettle();

    expect(find.text('SIRET vérifié'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
  });

  testWidgets('nettoie le préfixe Exception puis efface l erreur à la saisie',
      (tester) async {
    var changes = 0;
    await pumpSection(
      tester,
      preVerifier: (_) async => throw Exception('Service SIRET indisponible'),
      onSiretChanged: (_) => changes += 1,
    );
    await tester.enterText(find.byType(TextFormField), _verifiedSiret);

    await tester.tap(find.text('Vérifier mon SIRET'));
    await tester.pumpAndSettle();

    expect(find.text('Service SIRET indisponible'), findsOneWidget);
    expect(find.textContaining('Exception:'), findsNothing);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '73282932000075');
    await tester.pump();

    expect(find.text('Service SIRET indisponible'), findsNothing);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    expect(changes, 2);
  });

  testWidgets('masque proprement un message d erreur vide', (tester) async {
    await pumpSection(
      tester,
      preVerifier: (_) async => throw Exception('   '),
    );
    await tester.enterText(find.byType(TextFormField), _verifiedSiret);

    await tester.tap(find.text('Vérifier mon SIRET'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    expect(find.text('Vérifier mon SIRET'), findsOneWidget);
  });
}
