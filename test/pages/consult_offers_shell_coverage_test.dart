import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/consult_offers_page.dart';
import 'package:presto_app/services/city_search.dart';

class _SignedOutConsultAuthPlatform extends FirebaseAuthPlatform {
  _SignedOutConsultAuthPlatform() : super(appInstance: null);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({InternalUserDetails? currentUser, String? languageCode}) => this;

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuthPlatform originalAuthPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    originalAuthPlatform = FirebaseAuthPlatform.instance;
    FirebaseAuthPlatform.instance = _SignedOutConsultAuthPlatform();
  });

  tearDownAll(() {
    FirebaseAuthPlatform.instance = originalAuthPlatform;
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    String? categoryFilter,
    CitySearch? citySearchForTesting,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ConsultOffersPage(
          categoryFilter: categoryFilter,
          citySearchForTesting: citySearchForTesting,
        ),
      ),
    );
    for (var i = 0; i < 5; i += 1) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> drainQueryTimeouts(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 13));
    await tester.pump();
  }

  testWidgets('ouvre et referme le panneau de filtres sans backend réel', (tester) async {
    await pumpPage(tester);

    expect(find.text('Je consulte les offres'), findsOneWidget);
    expect(find.text('Filtres'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);

    await tester.tap(find.text('Filtres'));
    await tester.pump();
    expect(find.byType(TextField), findsWidgets);
    expect(find.byType(DropdownButtonFormField<String>), findsWidgets);

    await tester.tap(find.text('Filtres'));
    await tester.pump();
    expect(find.text('Filtres'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await drainQueryTimeouts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('garde le panneau ouvert en auto-application puis le ferme sur demande', (tester) async {
    final citySearch = CitySearch.forTesting(<CityRecord>[
      CityRecord(
        name: 'Les Abymes',
        postalCode: '97139',
        departmentCode: '971',
        regionCode: '01',
      ),
    ]);
    await pumpPage(tester, citySearchForTesting: citySearch);
    await tester.tap(find.text('Filtres'));
    await tester.pump(const Duration(milliseconds: 350));

    final categoryDropdown = find.byType(DropdownButton<String>).first;
    await tester.tap(categoryDropdown);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Bricolage / Travaux').last);
    await tester.pump();

    final regionDropdown = find.byType(DropdownButton<String?>).first;
    await tester.tap(regionDropdown);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Guadeloupe').last);
    await tester.pump();

    final cityField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Ville',
    );
    await tester.enterText(cityField, 'Les Abymes');
    await tester.pump(const Duration(milliseconds: 100));
    final citySuggestion = find.text('Les Abymes (97139)');
    expect(citySuggestion, findsOneWidget);
    await tester.tap(citySuggestion);
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade).first)
          .crossFadeState,
      CrossFadeState.showFirst,
    );
    expect(find.text('Rechercher'), findsOneWidget);

    await tester.tap(find.text('Rechercher'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade).first)
          .crossFadeState,
      CrossFadeState.showSecond,
    );
    expect(tester.takeException(), isNull);

    await drainQueryTimeouts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catégorie initiale construit le titre et la puce catégorie', (tester) async {
    await pumpPage(tester, categoryFilter: 'Bricolage');

    expect(find.textContaining('Offres :'), findsOneWidget);
    expect(find.textContaining('Catégorie:'), findsOneWidget);
    expect(find.text('Filtres'), findsOneWidget);
    expect(find.byType(InputChip), findsWidgets);

    final chip = tester.widget<InputChip>(find.byType(InputChip).first);
    chip.onDeleted?.call();
    await tester.pump();

    expect(find.text('Je consulte les offres'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);

    await drainQueryTimeouts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans filtre se dispose proprement après rendu du shell', (tester) async {
    await pumpPage(tester);

    expect(find.text('Je consulte les offres'), findsOneWidget);
    expect(find.text('Filtres'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);

    await drainQueryTimeouts(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
