import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/phone_input_field.dart';

void main() {
  test('résout les indicatifs et les hints avec replis sûrs', () {
    expect(phoneCountryFromCode(null).code, '+33');
    expect(phoneCountryFromCode('+590').label, contains('Guadeloupe'));
    expect(phoneCountryFromCode('+999').code, '+33');

    expect(phoneHintForCountryCode('+590'), '690123456');
    expect(phoneHintForCountryCode('+596'), '696123456');
    expect(phoneHintForCountryCode('+594'), '694123456');
    expect(phoneHintForCountryCode('+262'), '692123456');
    expect(phoneHintForCountryCode('+689'), '87123456');
    expect(phoneHintForCountryCode('+33'), '612345678');
    expect(phoneHintForCountryCode(null), '612345678');
  });

  testWidgets('champ standard filtre la saisie et change de pays', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final countryChanges = <String>[];
    final phoneChanges = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhoneInputField(
            controller: controller,
            initialCountryCode: '+590',
            labelText: 'Mobile',
            decoration: const InputDecoration(helperText: 'Numéro joignable'),
            onCountryCodeChanged: countryChanges.add,
            onPhoneChanged: phoneChanges.add,
            validator: (value) => value == null || value.isEmpty ? 'Requis' : null,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(countryChanges, <String>['+590']);
    expect(find.text('Mobile'), findsOneWidget);
    expect(find.text('690123456'), findsOneWidget);
    expect(find.text('Numéro joignable'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'a12- 3+');
    expect(controller.text, '12 3+');
    expect(phoneChanges.last, '12 3+');

    await tester.tap(find.byType(DropdownButton<CountryCode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇲🇶 +596').last);
    await tester.pumpAndSettle();

    expect(countryChanges.last, '+596');
    expect(find.text('696123456'), findsOneWidget);
  });

  testWidgets('variantes standard et compacte réagissent à une nouvelle valeur',
      (tester) async {
    final standardController = TextEditingController();
    final compactController = TextEditingController();
    addTearDown(standardController.dispose);
    addTearDown(compactController.dispose);
    final standardChanges = <String>[];
    final compactChanges = <String>[];

    Widget build(String code) => MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                PhoneInputField(
                  key: const ValueKey('standard'),
                  controller: standardController,
                  initialCountryCode: code,
                  label: const Text('Téléphone principal'),
                  hintText: 'Hint personnalisé',
                  onCountryCodeChanged: standardChanges.add,
                ),
                PhoneInputFieldCompact(
                  key: const ValueKey('compact'),
                  controller: compactController,
                  initialCountryCode: code,
                  labelText: 'Téléphone compact',
                  onCountryCodeChanged: compactChanges.add,
                ),
              ],
            ),
          ),
        );

    await tester.pumpWidget(build('+33'));
    await tester.pump();
    expect(standardChanges.last, '+33');
    expect(compactChanges.last, '+33');
    expect(find.text('Téléphone principal'), findsOneWidget);
    expect(find.text('Hint personnalisé'), findsOneWidget);

    await tester.pumpWidget(build('+689'));
    await tester.pump();
    await tester.pump();

    expect(standardChanges.last, '+689');
    expect(compactChanges.last, '+689');
    expect(find.text('87123456'), findsOneWidget);
  });
}
