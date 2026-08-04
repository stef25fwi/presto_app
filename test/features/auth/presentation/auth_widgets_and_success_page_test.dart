import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/auth/presentation/widgets/auth_error_box.dart';
import 'package:presto_app/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:presto_app/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:presto_app/pages/auth/reset_password_success_page.dart';

void main() {
  Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('AuthErrorBox', () {
    testWidgets('ne rend rien pour un message vide', (tester) async {
      await tester.pumpWidget(app(const AuthErrorBox(message: '   ')));

      expect(find.byType(Container), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('affiche le message et l’icône d’erreur', (tester) async {
      await tester.pumpWidget(
        app(const AuthErrorBox(message: 'Connexion impossible')),
      );

      expect(find.text('Connexion impossible'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });
  });

  group('AuthPrimaryButton', () {
    testWidgets('déclenche le callback avec l’icône par défaut', (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        app(
          AuthPrimaryButton(
            label: 'Connexion',
            onPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.text('Connexion'), findsOneWidget);
      expect(find.byIcon(Icons.login_rounded), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(pressed, isTrue);
    });

    testWidgets('affiche le chargement et désactive le bouton', (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        app(
          AuthPrimaryButton(
            label: 'Connexion',
            isLoading: true,
            icon: Icons.person,
            onPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.text('Veuillez patienter…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      await tester.tap(find.byType(FilledButton));
      expect(pressed, isFalse);
    });

    testWidgets('utilise l’icône fournie', (tester) async {
      await tester.pumpWidget(
        app(
          const AuthPrimaryButton(
            label: 'Créer',
            icon: Icons.person_add,
            onPressed: null,
          ),
        ),
      );

      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });
  });

  group('AuthTextField', () {
    testWidgets('transmet toutes les options au champ', (tester) async {
      final controller = TextEditingController(text: 'initial');
      addTearDown(controller.dispose);
      String? submitted;

      await tester.pumpWidget(
        app(
          AuthTextField(
            controller: controller,
            label: 'E-mail',
            hintText: 'nom@exemple.fr',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            obscureText: true,
            enabled: true,
            autofocus: true,
            suffixIcon: const Icon(Icons.visibility),
            validator: (value) => value == 'ok' ? null : 'Erreur',
            onFieldSubmitted: (value) => submitted = value,
          ),
        ),
      );

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.controller, same(controller));
      expect(editable.keyboardType, TextInputType.emailAddress);
      expect(editable.textInputAction, TextInputAction.done);
      expect(editable.autofillHints, contains(AutofillHints.email));
      expect(editable.obscureText, isTrue);
      expect(field.enabled, isTrue);
      expect(editable.autofocus, isTrue);
      expect(field.validator?.call('ko'), 'Erreur');
      expect(field.validator?.call('ok'), isNull);
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('nom@exemple.fr'), findsOneWidget);
      expect(find.byIcon(Icons.email), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      editable.onSubmitted?.call('envoyé');
      expect(submitted, 'envoyé');
    });

    testWidgets('respecte les valeurs par défaut', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        app(
          AuthTextField(
            controller: controller,
            label: 'Nom',
            icon: Icons.person,
          ),
        ),
      );

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.obscureText, isFalse);
      expect(field.enabled, isTrue);
      expect(editable.autofocus, isFalse);
      expect(field.validator, isNull);
      expect(editable.onSubmitted, isNull);
    });
  });

  testWidgets('ResetPasswordSuccessPage affiche l’email et revient à la racine',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ResetPasswordSuccessPage(
                    email: 'test@exemple.fr',
                  ),
                ),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('E-mail envoyé'), findsOneWidget);
    expect(find.text('Consultez votre boîte e-mail'), findsOneWidget);
    expect(find.textContaining('test@exemple.fr'), findsOneWidget);
    expect(find.textContaining('iliprestō'), findsOneWidget);
    expect(find.byIcon(Icons.mark_email_read), findsOneWidget);

    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();

    expect(find.text('Ouvrir'), findsOneWidget);
    expect(find.text('Consultez votre boîte e-mail'), findsNothing);
  });
}
