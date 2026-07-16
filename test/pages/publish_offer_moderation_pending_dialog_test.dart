import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/publish_offer_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Completer<void>> openDialog(WidgetTester tester) async {
    final completed = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                await showModerationPendingDialog(context);
                completed.complete();
              },
              child: const Text('Publier'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Publier'));
    await tester.pump();
    return completed;
  }

  Future<void> waitForDialogToClose(WidgetTester tester) async {
    for (var frame = 0; frame < 20; frame += 1) {
      if (find.byType(Dialog).evaluate().isEmpty) return;
      await tester.pump(const Duration(milliseconds: 16));
    }
    fail('Le dialogue de modération ne s’est pas fermé après son animation.');
  }

  testWidgets('affiche le verdict de modération et bloque la fermeture manuelle',
      (tester) async {
    final completed = await openDialog(tester);

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('Annonce en attente de validation'), findsOneWidget);
    expect(
      find.text(
        'Votre annonce est en cours de vérification. Elle sera publiée si elle respecte les règles de modération.',
      ),
      findsOneWidget,
    );
    expect(completed.isCompleted, isFalse);

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();

    expect(find.byType(Dialog), findsOneWidget);
    expect(completed.isCompleted, isFalse);

    await tester.pump(const Duration(seconds: 2));
    await waitForDialogToClose(tester);
    expect(find.byType(Dialog), findsNothing);
    expect(completed.isCompleted, isTrue);
  });

  testWidgets('reste visible avant deux secondes puis résout après fermeture',
      (tester) async {
    final completed = await openDialog(tester);

    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.text('Annonce en attente de validation'), findsOneWidget);
    expect(completed.isCompleted, isFalse);

    await tester.pump(const Duration(milliseconds: 1));
    await waitForDialogToClose(tester);

    expect(find.text('Annonce en attente de validation'), findsNothing);
    expect(completed.isCompleted, isTrue);
  });
}
