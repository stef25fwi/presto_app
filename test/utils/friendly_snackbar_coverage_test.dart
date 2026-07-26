import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/utils/friendly_snackbar.dart';

void main() {
  test('reconnaît les erreurs timeout locales et Firebase', () {
    expect(isTimeoutError(TimeoutException('lent')), isTrue);
    expect(
      isTimeoutError(
        FirebaseFunctionsException(
          code: 'deadline-exceeded',
          message: 'lent',
        ),
      ),
      isTrue,
    );
    expect(
      isTimeoutError(
        FirebaseFunctionsException(code: 'internal', message: 'erreur'),
      ),
      isFalse,
    );
  });

  testWidgets('affiche les snackbars timeout, succès et erreur', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (builderContext) {
              context = builderContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    showTimeoutSnackBar(context);
    await tester.pump();
    expect(find.text('Connexion lente, réessaie.'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    showSuccessSnackBar(context, 'Opération réussie');
    await tester.pump();
    expect(find.text('Opération réussie'), findsOneWidget);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    showErrorSnackBar(context, 'Opération refusée');
    await tester.pump();
    expect(find.text('Opération refusée'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);
  });
}
