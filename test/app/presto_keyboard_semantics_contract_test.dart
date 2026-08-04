import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/theme.dart';

void main() {
  testWidgets('les actions principales sont accessibles et activables au clavier', (
    tester,
  ) async {
    var primaryActivated = false;
    var secondaryActivated = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPrestoTheme(),
        home: Scaffold(
          body: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Column(
              children: [
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: FilledButton(
                    onPressed: () => primaryActivated = true,
                    child: const Text('Publier'),
                  ),
                ),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(2),
                  child: TextButton(
                    onPressed: () => secondaryActivated = true,
                    child: const Text('Annuler'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isA<Focus>(),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(primaryActivated, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(secondaryActivated, isTrue);
  });

  testWidgets('les icônes seules exposent un libellé sémantique exploitable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPrestoTheme(),
        home: Scaffold(
          body: Semantics(
            button: true,
            label: 'Ouvrir les notifications',
            child: IconButton(
              tooltip: 'Ouvrir les notifications',
              onPressed: () {},
              icon: const Icon(Icons.notifications_outlined),
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Ouvrir les notifications'),
      findsOneWidget,
    );
  });

  testWidgets('un état de chargement est annoncé sans exposer de détail technique', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPrestoTheme(),
        home: const Scaffold(
          body: Semantics(
            liveRegion: true,
            label: 'Chargement en cours',
            child: ExcludeSemantics(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Chargement en cours'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });
}
