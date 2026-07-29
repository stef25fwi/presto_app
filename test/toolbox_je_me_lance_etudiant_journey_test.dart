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

Future<void> _enterTextIfPresent(
  WidgetTester tester,
  Finder finder,
  String value,
) async {
  if (finder.evaluate().isEmpty) return;
  await tester.enterText(finder.last, value);
  await _settle(tester);
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
      // Les erreurs de layout ne sont plus neutralisées : tout overflow ou
      // usage Material invalide doit faire échouer le test et bloquer la CI.

      tester.view.physicalSize = const Size(430, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await tester
            .pumpWidget(const MaterialApp(home: ToolboxJeMeLancePage()));
        // Attente réelle (pas horloge fake) : tester.pump(Duration) n'avance
        // que l'horloge simulée, il ne laisse pas le temps à un vrai file
        // read (chargement des assets fiches) de se terminer.
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

        // --- Étape 2 : statut = Étudiant ---
        await tester.tap(find.text('Étudiant'));
        await _settle(tester);
        await tester.tap(find.text('Continuer'));
        await _settle(tester);

        // --- Étape 3 : activité = Service en salle (présente dans le pack étudiant) ---
        await tester.tap(find.text('Choisir une activité'));
        await _settle(tester);

        final activityOption = find.text('Service en salle');
        await tester.dragUntilVisible(
          activityOption,
          find.byType(Scrollable).last,
          const Offset(0, -300),
        );
        await _settle(tester);

        await tester.tap(activityOption.last);
        await _settle(tester);
        await tester.tap(find.text('Continuer'));
        await _settle(tester);

        // --- Étape 4 : validation -> ouvre "Mon parcours personnalisé" ---
        expect(find.text('Service en salle'), findsWidgets);
        await tester.tap(find.text('Voir mon parcours personnalisé'));
        await Future<void>.delayed(const Duration(seconds: 1));
        await _settle(tester, times: 20);

        // Le parcours généré s'ouvre désormais dans le renderer guidé par
        // étapes : la fiche officielle n'est plus déversée dans une longue
        // page de synthèse, elle alimente le contenu de chaque étape. On
        // vérifie donc que ce sont bien les données de la fiche Étudiant +
        // Service en salle qui remontent, et non le texte générique de repli.

        // Aperçu : la phrase d'introduction reprend l'activité, la région et
        // le statut réellement choisis.
        expect(
          find.text(
            'Créer une activité de Service en salle en Guadeloupe '
            'avec le statut actuel : Étudiant.',
          ),
          findsOneWidget,
        );
        expect(find.text('0 étape(s) terminée(s) sur 8'), findsOneWidget);

        // --- Étape 1 : règles de l'activité ---
        await tester.tap(find.text('Commencer l’étape 1'));
        await _settle(tester, times: 20);

        expect(find.text('Étape 1 sur 8'), findsWidgets);
        expect(
          find.textContaining(
            'Pour une activité de Service en salle en Guadeloupe',
          ),
          findsOneWidget,
        );

        // Alertes bloquantes propres au statut Étudiant (regles_etudiant.*),
        // regroupées sous « À vérifier avant de continuer ».
        expect(find.text('À vérifier avant de continuer'), findsOneWidget);
        expect(find.textContaining('Étudiant mineur'), findsWidgets);
        expect(find.textContaining('titre de séjour étudiant'), findsWidgets);
        expect(find.textContaining('Crous'), findsWidgets);

        // La checklist de l'étape est construite à partir de la fiche
        // (activité nommée, alertes et source officielle), pas d'un gabarit.
        expect(find.text('Activité : Service en salle'), findsOneWidget);
        expect(
          find.text('Alertes spécifiques à l’activité'),
          findsOneWidget,
        );
        expect(find.textContaining('Source officielle'), findsWidgets);

        // --- Étape 8 : le plan 30 jours reprend le cadrage de la fiche ---
        await tester.tap(find.byTooltip('Vue d’ensemble'));
        await _settle(tester, times: 20);

        final lastStage = find.text('Suivre mon plan sur 30 jours');
        await tester.dragUntilVisible(
          lastStage,
          find.byType(Scrollable).first,
          const Offset(0, -200),
        );
        await tester.tap(lastStage.last);
        await _settle(tester, times: 20);

        expect(find.text('Étape 8 sur 8'), findsWidgets);
        expect(
          find.textContaining('Vérifier situation étudiant, âge, titre de séjour'),
          findsWidgets,
        );
      });
    },
  );
}
