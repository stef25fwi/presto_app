import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/operating_mode/app_operating_mode.dart';
import 'package:presto_app/features/operating_mode/legal_publisher_admin_form.dart';

void main() {
  Widget app({
    required Future<void> Function(LegalPublisherProfile profile) onSave,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LegalPublisherAdminForm(
            initial: const LegalPublisherProfile.defaults(),
            mode: AppOperatingMode.freeBeta,
            onSave: onSave,
          ),
        ),
      ),
    );
  }

  testWidgets('valide et transmet les cinq informations obligatoires',
      (tester) async {
    LegalPublisherProfile? saved;
    await tester.pumpWidget(app(onSave: (profile) async => saved = profile));

    await tester.enterText(
      find.byKey(const ValueKey<String>('legal_publisherName')),
      'Stéphane Sahai',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('legal_postalAddress')),
      '1 rue Exemple, 97122 Baie-Mahault',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('legal_phone')),
      '0590 00 00 00',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('legal_email')),
      'adresse-invalide',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('legal_publicationDirector')),
      'Stéphane Sahai',
    );

    final saveButton =
        find.byKey(const ValueKey<String>('save_legal_publisher'));
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pump();

    expect(find.text('Adresse e-mail invalide'), findsOneWidget);
    expect(saved, isNull);

    await tester.enterText(
      find.byKey(const ValueKey<String>('legal_email')),
      'contact@example.fr',
    );
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.publisherName, 'Stéphane Sahai');
    expect(saved!.postalAddress, '1 rue Exemple, 97122 Baie-Mahault');
    expect(saved!.phone, '0590 00 00 00');
    expect(saved!.email, 'contact@example.fr');
    expect(saved!.publicationDirector, 'Stéphane Sahai');
  });
}
