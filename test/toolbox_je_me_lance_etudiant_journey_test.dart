import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:presto_app/pages/toolbox_je_me_lance_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fausse implémentation minimale de FirebaseAuthPlatform : simule un
/// environnement où l'auth anonyme échoue immédiatement (comme quand
/// l'auth anonyme est désactivée côté Firebase), pour exercer le mode
/// local de ToolboxJeMeLancePage sans dépendre d'un vrai channel Firebase
/// (qui resterait bloqué indéfiniment dans flutter test faute de handler).
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _FakeAuthPlatform();
    // _completeJourney() écrit un instantané d'historique local
    // (JourneyLocalStorageService) : sans ce mock, SharedPreferences n'a
    // pas de handler de canal disponible en test.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'le statut Étudiant + activité du catalogue alimente le parcours avec la fiche officielle',
    (tester) async {
      // La page contient des avertissements de layout préexistants
      // (débordement de l'indicateur d'étapes du header, ListTile sans
      // Material ancestor dans le picker d'activité) sans lien avec le
      // pipeline de fiches ; on ne laisse pas ce bruit faire échouer ce
      // test de bout en bout.
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
        // Attente réelle (pas horloge fake) : tester.pump(Duration) n'avance
        // que l'horloge simulée, il ne laisse pas le temps à un vrai file
        // read (chargement des assets fiches) de se terminer.
        await Future<void>.delayed(const Duration(seconds: 2));
        await tester.pump();

        // --- Étape 1 : région ---
        await tester.tap(find.text('Choisir votre région...'));
        await _settle(tester);
        final regionSearch = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Rechercher une région...',
        );
        await tester.enterText(regionSearch, 'Guadeloupe');
        await _settle(tester);
        await tester.tap(find.text('Guadeloupe').last);
        await _settle(tester);
        await tester.tap(find.text('Continuer'));
        await _settle(tester);

        // --- Étape 2 : statut = Étudiant ---
        await tester.tap(find.text('Étudiant'));
        await _settle(tester);
        await tester.tap(find.text('Continuer'));
        await _settle(tester);

        // --- Étape 3 : activité = Service en salle (présente dans le pack étudiant) ---
        await tester.tap(find.text('Choisir une activité'));
        await _settle(tester);
        final activitySearch = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Rechercher une activité',
        );
        await tester.enterText(activitySearch, 'Service en salle');
        await _settle(tester);
        await tester.tap(find.text('Service en salle').last);
        await _settle(tester);
        await tester.tap(find.text('Continuer'));
        await _settle(tester);

        // --- Étape 4 : validation -> ouvre "Mon parcours personnalisé" ---
        expect(find.text('Service en salle'), findsWidgets);
        await tester.tap(find.text('Voir mon parcours personnalisé'));
        await Future<void>.delayed(const Duration(seconds: 1));
        await _settle(tester, times: 20);

        // Section "1. Comprendre les règles" : contenu de la fiche, pas le
        // texte générique de repli.
        expect(
          find.textContaining('Code APE indicatif : 56.10A'),
          findsOneWidget,
        );

        // Section "2. Vérifier votre situation personnelle" : titre et
        // résumé propres au statut Étudiant (regles_etudiant), pas le texte
        // générique "Cumul d'activité".
        expect(
          find.text('Points à vérifier avant de démarrer — Service en salle'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Un étudiant peut créer une micro-entreprise'),
          findsOneWidget,
        );

        // Alertes bloquantes issues de regles_etudiant.mineur /
        // regles_etudiant.titre_sejour, remontées dans la section 1.
        expect(
          find.textContaining('Étudiant mineur'),
          findsOneWidget,
        );
        expect(
          find.textContaining('titre de séjour étudiant'),
          findsOneWidget,
        );

        // Scroll jusqu'aux étapes 4-9 pour vérifier l'enrichissement du plan
        // d'action (ListView : les sections hors-écran ne sont montées
        // qu'une fois scrollées en vue).
        for (var i = 0; i < 6; i++) {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
          await _settle(tester, times: 5);
        }
        expect(find.textContaining('Crous'), findsWidgets);
        expect(
          find.textContaining(
            'Dispositif identifié pour l’activité « Service en salle » (fiche officielle).',
          ),
          findsWidgets,
        );

        // Plan 30 jours : cadrage hebdomadaire propre à la fiche, injecté en
        // tête de chaque semaine, en plus des tâches génériques.
        for (var i = 0; i < 6; i++) {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
          await _settle(tester, times: 5);
        }
        expect(
          find.textContaining('Vérifier situation étudiant, âge, titre de séjour'),
          findsOneWidget,
        );
      });
    },
  );
}
