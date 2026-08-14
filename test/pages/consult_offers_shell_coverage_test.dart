import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/consult_offers_page.dart';

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

  Future<void> pumpPage(WidgetTester tester, {String? categoryFilter}) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: ConsultOffersPage(categoryFilter: categoryFilter)));
    for (var i = 0; i < 5; i += 1) {
      await tester.pump(const Duration(milliseconds: 80));
    }
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
    expect(find.byType(TextField), findsNothing);
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans filtre se dispose proprement après rendu du shell', (tester) async {
    await pumpPage(tester);

    expect(find.text('Je consulte les offres'), findsOneWidget);
    expect(find.text('Filtres'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
