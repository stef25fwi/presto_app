import 'dart:async';

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
  _ListTokenResult()
      : super(
          InternalIdTokenResult(
            token: 'messages-list-test-token',
            claims: const <String?, Object?>{},
            authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
}

class _ListUserPlatform extends UserPlatform {
  _ListUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _ListMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'user-messages',
              email: 'user-messages@ilipresto.fr',
              displayName: 'Utilisateur messages',
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
                'uid': 'user-messages',
                'email': 'user-messages@ilipresto.fr',
                'displayName': 'Utilisateur messages',
                'phoneNumber': null,
                'photoURL': null,
                'isAnonymous': false,
                'isEmailVerified': true,
              },
            ],
          ),
        );

  int tokenCalls = 0;
  int tokenResultCalls = 0;

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    tokenCalls += 1;
    return 'messages-list-test-token';
  }

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async {
    tokenResultCalls += 1;
    return _ListTokenResult();
  }
}

class _ListAuthPlatform extends FirebaseAuthPlatform {
  _ListAuthPlatform() : super(appInstance: null);

  final StreamController<UserPlatform?> controller =
      StreamController<UserPlatform?>.broadcast();
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
  Stream<UserPlatform?> authStateChanges() => controller.stream;

  @override
  Stream<UserPlatform?> idTokenChanges() => controller.stream;

  @override
  Stream<UserPlatform?> userChanges() => controller.stream;
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

  tearDownAll(() async {
    await authPlatform.controller.close();
  });

  Future<_ListUserPlatform> pumpConnectedPipeline(
    WidgetTester tester, {
    double width = 430,
    String title = 'Messagerie connectée',
  }) async {
    final user = _ListUserPlatform(authPlatform);
    authPlatform.user = user;
    await tester.binding.setSurfaceSize(Size(width, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ConversationsListPage(appBarTitle: title),
      ),
    );

    // Le runner ne fournit pas de plugin Firestore natif. On laisse néanmoins
    // le vrai pipeline exécuter le préflight, les deux délais App Check et la
    // préparation de la requête avant de vérifier son état de chargement sûr.
    for (var frame = 0; frame < 110; frame += 1) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    return user;
  }

  Future<void> disposeList(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('le compte connecté parcourt le pipeline puis garde un loader sûr',
      (tester) async {
    final user = await pumpConnectedPipeline(tester);

    expect(find.text('Messagerie connectée'), findsOneWidget);
    expect(find.text('ilipresto'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.text('Connexion / inscription pour accéder à la messagerie.'),
      findsNothing,
    );
    expect(user.tokenCalls, greaterThan(0));
    expect(user.tokenResultCalls, greaterThan(0));

    authPlatform.user = null;
    authPlatform.controller.add(null);
    await tester.pump();

    expect(
      find.text('Connexion / inscription pour accéder à la messagerie.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await disposeList(tester);
  });

  test('la page conserve ses paramètres publics et son style système', () {
    const page = ConversationsListPage(
      initialConversationId: 'conversation-1',
      initialDraftText: 'Bonjour',
      appBarTitle: 'Messagerie personnalisée',
    );

    expect(page.initialConversationId, 'conversation-1');
    expect(page.initialDraftText, 'Bonjour');
    expect(page.appBarTitle, 'Messagerie personnalisée');
    expect(page.createState(), isA<State<ConversationsListPage>>());
    expect(kMessagesStatusBarStyle.statusBarColor, kPrestoOrange);
    expect(
      kMessagesStatusBarStyle.statusBarIconBrightness,
      Brightness.light,
    );
    expect(kMessagesPageBackground, const Color(0xFFFFFEFE));
  });
}
