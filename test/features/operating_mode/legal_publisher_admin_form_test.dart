import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/operating_mode/app_operating_mode.dart';
import 'package:presto_app/features/operating_mode/legal_publisher_admin_form.dart';

void main() {
  Widget app({
    required Future<void> Function(LegalPublisherProfile profile) onSave,
    LegalPublisherProfile initial = const LegalPublisherProfile.defaults(),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LegalPublisherAdminForm(
            initial: initial,
            mode: AppOperatingMode.freeBeta,
            onSave: onSave,
          ),
        ),
      ),
    );
  }

  const persistedProfile = LegalPublisherProfile(
    publisherName: 'Éditeur Production',
    postalAddress: '10 rue de Production, 97122 Baie-Mahault',
    phone: '0590123456',
    email: 'contact@ilipresto.fr',
    publicationDirector: 'Direction Publication',
    companyName: '',
    legalForm: '',
    siren: '',
    rcs: '',
    shareCapital: '',
    vatNumber: '',
    hostingProvider: 'Google Ireland Limited (Firebase Hosting)',
    hostingAddress: 'Gordon House, Barrow Street, Dublin 4, Irlande',
  );

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

  testWidgets('réhydrate les champs quand la fiche Firestore arrive',
      (tester) async {
    await tester.pumpWidget(app(onSave: (_) async {}));

    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey<String>('legal_publisherName')),
          )
          .controller!
          .text,
      isEmpty,
    );

    await tester.pumpWidget(
      app(
        initial: persistedProfile,
        onSave: (_) async {},
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey<String>('legal_publisherName')),
          )
          .controller!
          .text,
      'Éditeur Production',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey<String>('legal_postalAddress')),
          )
          .controller!
          .text,
      '10 rue de Production, 97122 Baie-Mahault',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey<String>('legal_phone')),
          )
          .controller!
          .text,
      '0590123456',
    );
  });

  testWidgets('ne remplace pas une saisie locale pendant la réhydratation',
      (tester) async {
    await tester.pumpWidget(app(onSave: (_) async {}));

    final publisherField =
        find.byKey(const ValueKey<String>('legal_publisherName'));
    await tester.enterText(publisherField, 'Saisie en cours');

    await tester.pumpWidget(
      app(
        initial: persistedProfile,
        onSave: (_) async {},
      ),
    );
    await tester.pump();

    expect(
      tester.widget<TextFormField>(publisherField).controller!.text,
      'Saisie en cours',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey<String>('legal_phone')),
          )
          .controller!
          .text,
      '0590123456',
    );
  });
}
