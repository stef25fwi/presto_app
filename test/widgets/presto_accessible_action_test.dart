import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/theme.dart';
import 'package:presto_app/widgets/home_bottom_nav_item.dart';
import 'package:presto_app/widgets/home_interactions.dart';
import 'package:presto_app/widgets/premium_info_button.dart';
import 'package:presto_app/widgets/presto_accessible_action.dart';

void main() {
  testWidgets('active une action une seule fois au clic, Entrée et Espace', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'action test');
    addTearDown(focusNode.dispose);
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPrestoTheme(),
        home: Scaffold(
          body: Center(
            child: PrestoAccessibleAction(
              focusNode: focusNode,
              semanticLabel: 'Ouvrir les détails',
              semanticHint: 'Affiche le détail de l’annonce',
              onActivate: () => calls += 1,
              child: const SizedBox(
                width: 160,
                height: 56,
                child: Center(child: Text('Détails')),
              ),
            ),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(calls, 2);

    await tester.tap(find.byType(PrestoAccessibleAction));
    await tester.pump();
    expect(calls, 3);
  });

  testWidgets('expose une sémantique de bouton sélectionné', (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPrestoTheme(),
        home: Scaffold(
          body: PrestoAccessibleAction(
            semanticLabel: 'Messages',
            semanticHint: 'Ouvrir cet onglet',
            semanticValue: '3 éléments non lus, onglet actif',
            selected: true,
            excludeChildSemantics: true,
            onActivate: () {},
            child: const SizedBox(
              width: 100,
              height: 60,
              child: Text('Contenu visuel ignoré'),
            ),
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.byType(PrestoAccessibleAction));
    expect(node.label, 'Messages');
    expect(node.hint, 'Ouvrir cet onglet');
    expect(node.value, '3 éléments non lus, onglet actif');
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(node.hasFlag(SemanticsFlag.isEnabled), isTrue);
    expect(node.hasAction(SemanticsAction.tap), isTrue);
  });

  testWidgets('une action désactivée ne peut pas être activée', (tester) async {
    final focusNode = FocusNode(debugLabel: 'action désactivée');
    addTearDown(focusNode.dispose);
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPrestoTheme(),
        home: Scaffold(
          body: PrestoAccessibleAction(
            focusNode: focusNode,
            semanticLabel: 'Action indisponible',
            enabled: false,
            onActivate: () => calls += 1,
            child: const SizedBox(width: 100, height: 56),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.tap(find.byType(PrestoAccessibleAction), warnIfMissed: false);
    await tester.pump();

    expect(calls, 0);
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('la catégorie Home expose un libellé et répond au clavier', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPrestoTheme(),
        home: Scaffold(
          body: HomeCategoryChip(
            icon: Icons.grass,
            label: 'Jardinage',
            onTap: () => calls += 1,
          ),
        ),
      ),
    );

    final action = find.byType(PrestoAccessibleAction);
    expect(action, findsOneWidget);
    final node = tester.getSemantics(action);
    expect(node.label, 'Catégorie Jardinage');
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('la navigation Home annonce sélection et badge', (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPrestoTheme(),
        home: Scaffold(
          body: HomeBottomNavItem(
            icon: Icons.message,
            label: 'Messages',
            selected: true,
            badgeCount: 2,
            onTap: () => calls += 1,
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.byType(PrestoAccessibleAction));
    expect(node.label, 'Messages');
    expect(node.value, contains('2 éléments non lus'));
    expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('le bouton premium ne déclenche pas deux fois le clic', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPrestoTheme(),
        home: Scaffold(
          body: Center(
            child: PremiumInfoButton(onTap: () => calls += 1),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));

    final action = find.byType(PrestoAccessibleAction);
    final node = tester.getSemantics(action);
    expect(node.label, 'Infos');
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);

    await tester.tap(action);
    await tester.pump();
    expect(calls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
