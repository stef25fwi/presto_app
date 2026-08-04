import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/presto_design_tokens.dart';
import 'package:presto_app/app/presto_states.dart';
import 'package:presto_app/app/theme.dart';
import 'package:presto_app/pages/admin_space_hub_page.dart';

/// Contrôles d’accessibilité exécutés sur des écrans réels.
///
/// Les vérifications de jetons prouvent que la palette est correcte ; elles ne
/// prouvent pas que l’interface rendue l’est. Ce fichier applique donc les
/// règles intégrées de Flutter — contraste, taille des cibles, libellés — sur
/// des arbres de widgets effectivement construits.

/// L’état de chargement anime un indicateur en continu : `pumpAndSettle`
/// n’atteindrait jamais le repos. Deux images suffisent à stabiliser l’arbre.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Widget _hosted(Widget child) {
  return MaterialApp(
    theme: buildPrestoTheme(),
    home: Scaffold(body: child),
  );
}

/// Chaque état partagé, avec son action lorsqu’il en propose une.
final Map<String, Widget> _sharedStates = <String, Widget>{
  'chargement': const PrestoLoadingState(
    message: 'Nous récupérons vos annonces.',
  ),
  'vide': PrestoEmptyState(
    title: 'Aucune annonce pour le moment',
    message: 'Publiez votre première annonce pour être visible.',
    actionLabel: 'Publier une annonce',
    onAction: () {},
  ),
  'erreur': PrestoErrorState(
    message: 'La connexion a échoué.',
    onRetry: () {},
  ),
  'succès': PrestoSuccessState(
    title: 'Annonce publiée',
    message: 'Elle est visible par les autres utilisateurs.',
    actionLabel: 'Voir l’annonce',
    onAction: () {},
  ),
};

void main() {
  group('règles d’accessibilité sur les états partagés', () {
    for (final entry in _sharedStates.entries) {
      testWidgets('l’état ${entry.key} respecte contraste, cibles et libellés', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_hosted(entry.value));
        await _settle(tester);

        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        handle.dispose();
      });
    }

    testWidgets('chaque état est annoncé comme région dynamique', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final entry in _sharedStates.entries) {
        await tester.pumpWidget(_hosted(entry.value));
        await _settle(tester);

        final liveRegion = find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.liveRegion == true,
        );
        expect(
          liveRegion,
          findsOneWidget,
          reason: 'L’état ${entry.key} n’est pas une région dynamique.',
        );
        expect(
          tester.getSemantics(liveRegion).label,
          isNotEmpty,
          reason: 'L’état ${entry.key} doit porter un libellé annonçable.',
        );
      }
      handle.dispose();
    });
  });

  group('règles d’accessibilité sur un écran réel', () {
    testWidgets('le hub d’administration respecte les règles intégrées', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(theme: buildPrestoTheme(), home: const AdminSpaceHubPage()),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    });
  });

  group('indicateur de focus', () {
    test('l’anneau de focus dépasse le seuil WCAG 2.2 sur les deux fonds', () {
      for (final background in <Color>[
        PrestoColors.surface,
        PrestoColors.scaffold,
      ]) {
        expect(
          prestoContrastRatio(PrestoColors.focusRing, background),
          greaterThanOrEqualTo(PrestoAccessibility.focusIndicatorContrast),
        );
      }
    });

    test('le remplissage discret ne peut pas servir d’indicateur', () {
      // Garde-fou explicite : c’est la confusion entre fond de focus et
      // indicateur de focus qui rendait la navigation clavier invisible.
      expect(
        prestoContrastRatio(PrestoColors.focus, PrestoColors.surface),
        lessThan(PrestoAccessibility.focusIndicatorContrast),
      );
    });

    test('chaque famille de boutons expose un anneau au focus', () {
      final theme = buildPrestoTheme();
      const focused = <WidgetState>{WidgetState.focused};

      final styles = <String, ButtonStyle?>{
        'texte': theme.textButtonTheme.style,
        'élevé': theme.elevatedButtonTheme.style,
        'plein': theme.filledButtonTheme.style,
        'contourné': theme.outlinedButtonTheme.style,
        'icône': theme.iconButtonTheme.style,
      };

      for (final entry in styles.entries) {
        final side = entry.value?.side?.resolve(focused);
        expect(
          side,
          isNotNull,
          reason: 'Le bouton ${entry.key} n’a aucun anneau de focus.',
        );
        expect(side!.color, PrestoColors.focusRing);
        expect(
          side.width,
          greaterThanOrEqualTo(PrestoAccessibility.focusRingWidth),
        );
      }
    });

    test('le champ de saisie reprend le même anneau', () {
      final border = buildPrestoTheme().inputDecorationTheme.focusedBorder;
      expect(border, isA<OutlineInputBorder>());
      expect(border!.borderSide.color, PrestoColors.focusRing);
      expect(
        border.borderSide.width,
        greaterThanOrEqualTo(PrestoAccessibility.focusRingWidth),
      );
    });

    testWidgets('la tabulation parcourt les actions dans l’ordre visuel', (
      tester,
    ) async {
      final first = FocusNode(debugLabel: 'action 1');
      final second = FocusNode(debugLabel: 'action 2');
      final third = FocusNode(debugLabel: 'action 3');
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      addTearDown(third.dispose);

      await tester.pumpWidget(
        _hosted(
          Column(
            children: <Widget>[
              TextButton(
                focusNode: first,
                onPressed: () {},
                child: const Text('Première action'),
              ),
              OutlinedButton(
                focusNode: second,
                onPressed: () {},
                child: const Text('Deuxième action'),
              ),
              FilledButton(
                focusNode: third,
                onPressed: () {},
                child: const Text('Troisième action'),
              ),
            ],
          ),
        ),
      );

      for (final node in <FocusNode>[first, second, third]) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(node.hasFocus, isTrue, reason: '${node.debugLabel} non atteint.');
      }
    });
  });
}
