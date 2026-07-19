import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/account_profile_sections.dart';

Finder _fieldWithLabel(String label) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == label,
  );
}

class _Controllers {
  final department = TextEditingController(text: '971');
  final pseudo = TextEditingController(text: 'Stef971');
  final city = TextEditingController();
  final phone = TextEditingController();

  void dispose() {
    department.dispose();
    pseudo.dispose();
    city.dispose();
    phone.dispose();
  }
}

void main() {
  Future<void> pumpProfile(
    WidgetTester tester, {
    required _Controllers controllers,
    required ValueChanged<String> onPhoneCountryCodeChanged,
  }) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AccountProfileFormSection(
              firstName: 'Stef',
              lastName: 'Stefan',
              departmentController: controllers.department,
              pseudoController: controllers.pseudo,
              cityController: controllers.city,
              phoneController: controllers.phone,
              phoneCountryCode: '+33',
              isEditing: true,
              isSaving: false,
              onStartEditing: () {},
              onSave: () async {},
              onPhoneCountryCodeChanged: onPhoneCountryCodeChanged,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('recherche une ville sans code postal puis sélectionne une option',
      (tester) async {
    final controllers = _Controllers();
    addTearDown(controllers.dispose);
    final countryCodes = <String>[];

    await pumpProfile(
      tester,
      controllers: controllers,
      onPhoneCountryCodeChanged: countryCodes.add,
    );

    final cityField = _fieldWithLabel('Ville');
    expect(cityField, findsOneWidget);

    await tester.tap(cityField);
    await tester.enterText(cityField, 'Baie-Mahault');
    await tester.pumpAndSettle();

    expect(countryCodes.last, '+33');
    final option = find.text('Baie-Mahault (97122)');
    expect(option, findsOneWidget);

    await tester.tap(option);
    await tester.pumpAndSettle();

    expect(controllers.city.text, 'Baie-Mahault (97122)');
    expect(countryCodes.last, '+590');
  });

  testWidgets('affiche le titre messages et transmet son action', (tester) async {
    var opens = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountMessagesSection(
            onOpenMessages: () => opens += 1,
          ),
        ),
      ),
    );

    expect(find.text('Mes messages'), findsOneWidget);
    expect(find.text('Ouvrir mes messages'), findsOneWidget);

    await tester.tap(find.text('Ouvrir mes messages'));
    await tester.pump();

    expect(opens, 1);
  });
}
