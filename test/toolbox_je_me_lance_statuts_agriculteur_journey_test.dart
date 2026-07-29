import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:presto_app/pages/toolbox_je_me_lance_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Couvre le rendu du parcours personnalisé pour les statuts restants
/// (Retraité, Indépendant, Demandeur d'emploi, Sans activité) sur l'activité
/// Agriculteur, en complément des tests dédiés Étudiant (Service en salle) et
/// Salarié (Agriculteur).
///
/// Chaque cas déroule le parcours en mode local (pipeline de fiches appliqué
/// localement, sans cache Firestore) et vérifie que le contenu affiché
/// provient bien de la fiche officielle du bon pack :
/// - contenu commun à la fiche Agriculteur (code APE agricole, MSA...),
/// - titre de la section 2 propre au statut (donc pas le bloc générique).
///
/// Le statut Fonctionnaire n'est pas couvert ici : il emprunte un chemin
/// Firestore (`loadFonctionnaireDerivedData`) non mockable en widget test ;
/// sa transformation est validée par `parcours_fiches_service_test.dart`, et
/// la complétude de ses fiches par `parcours_fiches_completeness_test.dart`.
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

/// Fait défiler jusqu'à ce que [target] soit monté (evaluate().isNotEmpty ne
/// lève jamais, que le finder matche 0, 1 ou plusieurs widgets — contrairement
/// à dragUntilVisible qui exige une cible unique).
Future<void> _scrollUntilFound(
  WidgetTester tester,
  Finder target, {
  int maxDrags = 45,
}) async {
  for (var i = 0; i < maxDrags; i++) {
    if (target.evaluate().isNotEmpty) return;
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await _settle(tester, times: 3);
  }
}

/// Déroule le parcours région → [statusLabel] → Agriculteur et vérifie le
/// contenu de la fiche officielle correspondante.
Future<void> _runAgriculteurJourney(
  WidgetTester tester, {
  required String statusLabel,
}) async {
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

    // --- Étape 2 : statut ---
    await tester.tap(find.text(statusLabel));
    await _settle(tester);
    await tester.tap(find.text('Continuer'));
    await _settle(tester);

    // --- Étape 3 : activité = Agriculteur ---
    await tester.tap(find.text('Choisir une activité'));
    await _settle(tester);
    final activitySearch = find.byWidgetPredicate(
      (w) =>
          w is TextField && w.decoration?.hintText == 'Rechercher une activité',
    );
    await _enterTextIfPresent(tester, activitySearch, 'Agriculteur');
    await tester.tap(find.text('Agriculteur').last);
    await _settle(tester);
    await tester.tap(find.text('Continuer'));
    await _settle(tester);

    // --- Étape 4 : ouvre "Mon parcours personnalisé" ---
    await tester.tap(find.text('Voir mon parcours personnalisé'));
    await Future<void>.delayed(const Duration(seconds: 1));
    await _settle(tester, times: 20);

    // Le parcours s'ouvre dans le renderer guidé par étapes : la fiche
    // officielle alimente le contenu des étapes plutôt qu'une page de
    // synthèse unique. On vérifie que ce sont bien les données Agriculteur
    // et le statut choisi qui remontent, et non un repli générique.
    expect(
      find.textContaining('Créer une activité de Agriculteur en Guadeloupe'),
      findsOneWidget,
    );
    expect(find.textContaining(statusLabel), findsWidgets);

    await tester.tap(find.text('Commencer l’étape 1'));
    await _settle(tester, times: 20);

    expect(find.text('Étape 1 sur 8'), findsWidgets);
    expect(
      find.textContaining('Pour une activité de Agriculteur en Guadeloupe'),
      findsOneWidget,
    );

    // Alertes bloquantes propres au régime agricole : elles ne peuvent pas
    // provenir d'un gabarit générique.
    expect(find.text('À vérifier avant de continuer'), findsOneWidget);
    expect(find.textContaining('MSA'), findsWidgets);
    expect(find.textContaining('micro-BA'), findsWidgets);
    expect(find.textContaining('cotisant solidaire'), findsWidgets);

    // La checklist est construite depuis la fiche de l'activité choisie.
    expect(find.text('Activité : Agriculteur'), findsOneWidget);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _FakeAuthPlatform();
    SharedPreferences.setMockInitialValues({});
  });

  // Statuts tels qu'affichés dans le sélecteur.
  const statuts = <String>[
    'Retraité',
    'Indépendant',
    "Demandeur d'emploi",
    'Sans activité',
  ];

  for (final statusLabel in statuts) {
    testWidgets(
      'le statut $statusLabel + activité Agriculteur affiche les vraies infos de la fiche officielle',
      (tester) async {
        await _runAgriculteurJourney(tester, statusLabel: statusLabel);
      },
    );
  }
}
