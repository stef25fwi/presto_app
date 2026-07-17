import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversations_list_page.dart';

class _ListMultiFactorPlatform extends MultiFactorPlatform {
  _ListMultiFactorPlatform(super.auth);
}

class _ListTokenResult extends IdTokenResult {
  _ListTokenResult({required bool isAdmin})
      : super(
          InternalIdTokenResult(
            token: 'messages-list-test-token',
            claims: <String?, Object?>{
              if (isAdmin) 'admin': true,
            },
            authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
}

class _ListUserPlatform extends UserPlatform {
  _ListUserPlatform(
    FirebaseAuthPlatform auth, {
    required this.isAdmin,
  }) : super(
          auth,
          _ListMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: isAdmin ? 'admin-messages' : 'user-messages',
              email: isAdmin
                  ? 'admin-messages@ilipresto.fr'
                  : 'user-messages@ilipresto.fr',
              displayName: isAdmin ? 'Admin messages' : 'Utilisateur messages',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp:
                  DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 17).millisecondsSinceEpoch,
            ),
            providerData: <Map<String, dynamic>?>[
              <String, dynamic>{
                'providerId': 'password',
                'uid': isAdmin ? 'admin-messages' : 'user-messages',
                'email': isAdmin
                    ? 'admin-messages@ilipresto.fr'
                    : 'user-messages@ilipresto.fr',
                'displayName':
                    isAdmin ? 'Admin messages' : 'Utilisateur messages',
                'phoneNumber': null,
                'photoURL': null,
                'isAnonymous': false,
                'isEmailVerified': true,
              },
            ],
          ),
        );

  final bool isAdmin;
  int reloadCalls = 0;

  @override
  Future<void> reload() async {
    reloadCalls += 1;
  }

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    return 'messages-list-test-token';
  }

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async {
    return _ListTokenResult(isAdmin: isAdmin);
  }
}

class _ListAuthPlatform extends FirebaseAuthPlatform {
  _ListAuthPlatform() : super(appInstance: null);

  UserPlatform? user;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => user;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(user);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ListAuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _ListAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  tearDown(() {
    authPlatform.user = null;
  });

  Future<void> pumpList(
    WidgetTester tester, {
    required bool isAdmin,
    double width = 430,
    String title = 'Messagerie connectée',
  }) async {
    authPlatform.user = _ListUserPlatform(authPlatform, isAdmin: isAdmin);
    await tester.binding.setSurfaceSize(Size(width, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ConversationsListPage(appBarTitle: title),
      ),
    );

    for (var frame = 0; frame < 180; frame += 1) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.text('Tous').evaluate().isNotEmpty &&
          find.text('Non lus').evaluate().isNotEmpty &&
          find.text('Archives').evaluate().isNotEmpty) {
        return;
      }
    }
    fail('La liste connectée ne s’est pas stabilisée après les retries prévus.');
  }

  Future<void> disposeList(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }

  Finder filterInkWell(String label) {
    return find.ancestor(
      of: find.text(label),
      matching: find.byType(InkWell),
    ).first;
  }

  Color? filterColor(WidgetTester tester, String label) {
    final container = find.ancestor(
      of: find.text(label),
      matching: find.byType(AnimatedContainer),
    ).first;
    final widget = tester.widget<AnimatedContainer>(container);
    return (widget.decoration as BoxDecoration?)?.color;
  }

  testWidgets('affiche le shell utilisateur et manipule recherche et filtres',
      (tester) async {
    await pumpList(tester, isAdmin: false);

    expect(find.text('Messagerie connectée'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('ilipresto'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Compte actuellement connecté'), findsNothing);
    expect(filterColor(tester, 'Tous'), kPrestoBlue);

    await tester.tap(find.byTooltip('Rechercher'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Rechercher une conversation'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'jardinage');
    await tester.pump();
    expect(find.byTooltip('Effacer la recherche'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'jardinage');

    await tester.tap(find.byTooltip('Effacer la recherche'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );

    await tester.tap(filterInkWell('Non lus'));
    await tester.pump(const Duration(milliseconds: 220));
    expect(filterColor(tester, 'Non lus'), kPrestoBlue);
    expect(filterColor(tester, 'Tous'), isNot(kPrestoBlue));

    await tester.tap(filterInkWell('Archives'));
    await tester.pump(const Duration(milliseconds: 220));
    expect(filterColor(tester, 'Archives'), kPrestoBlue);

    await tester.tap(filterInkWell('Tous'));
    await tester.pump(const Duration(milliseconds: 220));
    expect(filterColor(tester, 'Tous'), kPrestoBlue);

    await tester.tap(find.byTooltip('Fermer la recherche'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(TextField), findsNothing);

    await disposeList(tester);
  });

  testWidgets('affiche le diagnostic et les outils du compte administrateur',
      (tester) async {
    await pumpList(
      tester,
      isAdmin: true,
      title: 'Messagerie administration',
    );

    for (var frame = 0; frame < 80; frame += 1) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.text('Compte actuellement connecté').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Messagerie administration'), findsOneWidget);
    expect(find.text('Compte actuellement connecté'), findsOneWidget);
    expect(find.text('admin-messages@ilipresto.fr'), findsOneWidget);
    expect(find.text('UID: admin-messages'), findsOneWidget);
    expect(find.text('Log admin - chargement conversations'), findsOneWidget);
    expect(find.byTooltip('Copier les identifiants'), findsOneWidget);
    expect(find.byTooltip('Copier les logs'), findsOneWidget);

    await tester.tap(find.byTooltip('Copier les identifiants'));
    await tester.pump();
    expect(find.text('Identifiants du compte copiés.'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold)))
        .hideCurrentSnackBar();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byTooltip('Copier les logs'));
    await tester.pump();
    expect(find.text('Logs copiés dans le presse-papiers.'), findsOneWidget);

    await tester.tap(find.text('Log admin - chargement conversations'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(ExpansionTile), findsOneWidget);
    expect(find.byType(SelectableText), findsWidgets);

    await disposeList(tester);
  });

  testWidgets('affiche le panneau de conversation du mode large', (tester) async {
    await pumpList(
      tester,
      isAdmin: false,
      width: 1200,
      title: 'Messagerie large',
    );

    expect(find.text('Messagerie large'), findsOneWidget);
    expect(find.text('Sélectionnez une conversation'), findsOneWidget);
    expect(
      find.text(
        'Le fil restera ouvert ici pendant que vous parcourez vos messages.',
      ),
      findsOneWidget,
    );
    expect(find.byType(VerticalDivider), findsOneWidget);

    await disposeList(tester);
  });
}
