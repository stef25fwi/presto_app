import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:presto_app/pages/toolbox_je_me_lance_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fausse implémentation minimale de FirebaseAuthPlatform : simule un
/// environnement où l'auth anonyme échoue immédiatement (auth anonyme
/// désactivée côté Firebase), pour exercer le mode local de
/// ToolboxJeMeLancePage sans dépendre d'un vrai channel Firebase (qui
/// resterait bloqué indéfiniment dans flutter test faute de handler).
///
/// Ce mode local est important pour ce test : il force le calcul du parcours
/// via `_recomputeDerived` (fiche officielle appliquée localement) sans jamais
/// passer par le cache Firestore partagé, donc on vérifie bien le pipeline de
/// fiches lui-même.
class _FakeAuthPlatform extends FirebaseAuthPlatform {
  _FakeAuthPlatform() : super(appInstance: null);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => null;

  @override
  Future<UserCredentialPlatform> signInAnonymously() async {
    throw FirebaseAuthException(
      code: 'network-request-failed',
      message: 'mocked: no network in test',
    );
  }
}

/// pumpAndSettle boucle indéfiniment sur cette page (animations continues
/// dans le header), donc on avance le temps par incréments fixes.
Future<void> _settle(WidgetTester tester, {int times = 10}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _enterTextIfPresent(
  WidgetTester tester,
  Finder finder,
  String value,
) async {
  if (finder.evaluate().isEmpty) return;
  await tester.enterText(finder.last, value);
  await _settle(tester);
}

/// Fait défiler la liste (ListView) par pas fixes jusqu'à ce que [target] soit
/// effectivement monté dans l'arbre, puis s'arrête. Contrairement à
/// `tester.dragUntilVisible`, ceci ne suppose pas que [target] soit unique
/// (dragUntilVisible appelle `.element` et lève « Too many elements » si le
/// texte apparaît plusieurs fois — ce qui est le cas de plusieurs contenus de
/// fiche répétés entre sections). On teste `evaluate().isNotEmpty`, qui ne
/// lève jamais, que le finder matche 0, 1 ou plusieurs widgets.
Future<void> _scrollUntilFound(
  WidgetTester tester,
  Finder target, {
  int maxDrags = 45,
}) async {
  for (var i = 0; i < maxDrags; i++) {
    if (target.evaluate().isNotEmpty) return;
    // Pas de 700px : bien inférieur à la hauteur du viewport de test
    // (3200px + cacheExtent), donc aucune tuile n'est « sautée » entre deux
    // vérifications ; et 45 pas couvrent ~31 500px, largement de quoi
    // atteindre la section 6 (coûts) même après les sections 4-5 très hautes.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await _settle(tester, times: 3);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _FakeAuthPlatform();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'le statut Salarié + activité Agriculteur affiche les vraies infos de la fiche officielle (salarie_agriculteur)',
    (tester) async {
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final message = details.exception.toString();
        if (message.contains('RenderFlex overflowed') ||
            message.contains('ListTile background color')) {
          return;
        }
        oldOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldOnError);

      tester.view.physicalSize = const Size(430, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await tester.pumpWidget(const MaterialApp(home: ToolboxJeMeLancePage()));
        // Attente réelle (pas horloge fake) : laisse le chargement des assets
        // fiches (rootBundle) se terminer.
        await Future<void>.delayed(const Duration(seconds: 2));
        await tester.pump();

        // --- Étape 1 : région ---
        await tester.tap(find.text('Choisir votre région...'));
        await _settle(tester);
        final regionSearch = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Rechercher une région...',
        );
        await _enterTextIfPresent(tester, regionSearch, 'Guadeloupe');
        await tester.tap(find.text('Guadeloupe').last);
        await _settle(tester);
        await tester.tap(find.text('Continuer'));
        await _settle(tester);

        // --- Étape 2 : statut = Salarié ---
        await tester.tap(find.text('Salarié'));
        await _settle(tester);
        await tester.tap(find.text('Continuer'));
        await _settle(tester);

        // --- Étape 3 : activité = Agriculteur (catégorie Agriculture) ---
        await tester.tap(find.text('Choisir une activité'));
        await _settle(tester);
        final activitySearch = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Rechercher une activité',
        );
        await _enterTextIfPresent(tester, activitySearch, 'Agriculteur');
        await tester.tap(find.text('Agriculteur').last);
        await _settle(tester);
        await tester.tap(find.text('Continuer'));
        await _settle(tester);

        // --- Étape 4 : validation -> ouvre "Mon parcours personnalisé" ---
        await tester.tap(find.text('Voir mon parcours personnalisé'));
        await Future<void>.delayed(const Duration(seconds: 1));
        await _settle(tester, times: 20);

        // Section "1. Comprendre les règles" : contenu propre à la fiche
        // salarie_agriculteur, pas le texte générique de repli.
        // Code APE agricole (tuile "Activité : Agriculteur").
        expect(
          find.textContaining('Code APE indicatif : 01.xx'),
          findsWidgets,
        );
        // Niveau de vigilance réel de la fiche (tuile "Vue d'ensemble"),
        // et non le "Faible/Moyen" générique calculé par l'app.
        expect(
          find.textContaining('vigilance : très élevé'),
          findsWidgets,
        );

        // Organisme(s) de contrôle spécifiques à l'agriculture (MSA...),
        // qui n'existent que dans la fiche.
        await _scrollUntilFound(
          tester,
          find.textContaining('MSA, DAAF/DDT(M)'),
        );
        expect(find.textContaining('MSA, DAAF/DDT(M)'), findsWidgets);

        // Source officielle MSA micro-BA (tuile dédiée de la section 1).
        await _scrollUntilFound(
          tester,
          find.textContaining('MSA — Le régime du micro-BA'),
        );
        expect(
          find.textContaining('MSA — Le régime du micro-BA'),
          findsWidgets,
        );

        // Section "2. Vérifier votre situation personnelle" : titre et résumé
        // propres à la fiche (regles_statut), pas le bloc générique "Contrat
        // de travail à vérifier" du statut Salarié.
        await _scrollUntilFound(
          tester,
          find.text('Cumul d’activité — Agriculteur'),
        );
        expect(
          find.text('Cumul d’activité — Agriculteur'),
          findsOneWidget,
        );
        expect(
          find.textContaining('convention collective, clause d’exclusivité'),
          findsWidgets,
        );

        // Section "6. Prévoir les coûts" : coût agricole propre à la fiche
        // (cotisations MSA), affiché dans la liste des coûts détaillés.
        await _scrollUntilFound(
          tester,
          find.textContaining('cotisations MSA : à simuler'),
        );
        expect(
          find.textContaining('cotisations MSA : à simuler'),
          findsWidgets,
        );
      });
    },
  );
}
