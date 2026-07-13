import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/auth/presentation/widgets/auth_error_box.dart';
import 'package:presto_app/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:presto_app/features/auth/presentation/widgets/auth_text_field.dart';

void main() {
  testWidgets('AuthErrorBox se masque pour un message vide', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AuthErrorBox(message: '   '))),
    );

    expect(find.byType(Container), findsNothing);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
  });

  testWidgets('AuthErrorBox affiche le message et l icône', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AuthErrorBox(message: 'Erreur Auth')),
      ),
    );

    expect(find.text('Erreur Auth'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('AuthPrimaryButton appelle onPressed avec l icône choisie', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthPrimaryButton(
            label: 'Connexion',
            icon: Icons.person,
            onPressed: () => pressed += 1,
          ),
        ),
      ),
    );

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(pressed, 1);
  });

  testWidgets('AuthPrimaryButton désactive l action pendant le chargement', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthPrimaryButton(
            label: 'Connexion',
            isLoading: true,
            onPressed: () => pressed += 1,
          ),
        ),
      ),
    );

    expect(find.text('Veuillez patienter…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(pressed, 0);
  });

  testWidgets('AuthTextField transmet ses options et soumet la valeur', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'secret');
    addTearDown(controller.dispose);
    String? submitted;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: AuthTextField(
              controller: controller,
              label: 'Mot de passe',
              hintText: '8 caractères minimum',
              icon: Icons.lock,
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.password],
              suffixIcon: const Icon(Icons.visibility),
              validator: (value) => value == 'secret' ? null : 'Erreur',
              onFieldSubmitted: (value) => submitted = value,
            ),
          ),
        ),
      ),
    );

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.obscureText, isTrue);
    expect(field.keyboardType, TextInputType.visiblePassword);
    expect(field.textInputAction, TextInputAction.done);
    expect(field.autofillHints, contains(AutofillHints.password));
    expect(field.decoration?.labelText, 'Mot de passe');
    expect(field.decoration?.hintText, '8 caractères minimum');
    expect(find.byIcon(Icons.lock), findsOneWidget);
    expect(find.byIcon(Icons.visibility), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, 'secret');
  });

  testWidgets('AuthTextField respecte enabled et autofocus', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthTextField(
            controller: controller,
            label: 'Email',
            icon: Icons.email,
            enabled: false,
            autofocus: true,
          ),
        ),
      ),
    );

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.enabled, isFalse);
    expect(field.autofocus, isTrue);
  });
}
