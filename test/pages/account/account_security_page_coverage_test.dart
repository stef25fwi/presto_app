import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/account/account_security_page.dart';
import 'package:presto_app/pages/account/change_email_page.dart';
import 'package:presto_app/pages/account/change_password_page.dart';
import 'package:presto_app/pages/account/delete_account_page.dart';
import 'package:presto_app/pages/account/phone_verification_page.dart';
import 'package:presto_app/pages/auth/verify_email_page.dart';

class _SecurityMultiFactorPlatform extends MultiFactorPlatform {
  _SecurityMultiFactorPlatform(super.auth);
}

class _SecurityUserPlatform extends UserPlatform {
  _SecurityUserPlatform(
    FirebaseAuthPlatform auth, {
    required String uid,
    required String? email,
    required bool emailVerified,
    required String providerId,
    String? phoneNumber,
  }) : super(
          auth,
          _SecurityMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: uid,
              email: email,
              displayName: 'Utilisateur sécurité',
              phoneNumber: phoneNumber,
              isAnonymous: false,
              isEmailVerified: emailVerified,
              creationTimestamp:
                  DateTime(2026, 7, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 19).millisecondsSinceEpoch,
            ),
            providerData: <Map<String, dynamic>?>[
              <String, dynamic>{
                'providerId': providerId,
                'uid': uid,
                'email': email,
                'displayName': 'Utilisateur sécurité',
                'phoneNumber': phoneNumber,
                'photoURL': null,
                'isAnonymous': false,
                'isEmailVerified': emailVerified,
              },
            ],
          ),
        );

  var reloadCalls = 0;

  @override
  Future<void> reload() async {
    reloadCalls += 1;
  }
}

class _SecurityAuthPlatform extends FirebaseAuthPlatform {
  _SecurityAuthPlatform() : super(appInstance: null);

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
}

class _SecurityNavigatorObserver extends NavigatorObserver {
  Route<dynamic>? lastPushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) lastPushedRoute = route;
    super.didPush(route, previousRoute);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SecurityAuthPlatform platform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    platform = _SecurityAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  setUp(() {
    platform.user = null;
  });

  Future<_SecurityNavigatorObserver> pumpPage(WidgetTester tester) async {
    final observer = _SecurityNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: <NavigatorObserver>[observer],
        home: const AccountSecurityPage(),
      ),
    );
    await tester.pump();
    return observer;
  }

  Widget destinationOf(
    _SecurityNavigatorObserver observer,
    BuildContext context,
  ) {
    final route = observer.lastPushedRoute;
    expect(route, isA<MaterialPageRoute<dynamic>>());
    return (route! as MaterialPageRoute<dynamic>).builder(context);
  }

  testWidgets('affiche un email vérifié et son indicateur vert', (tester) async {
    platform.user = _SecurityUserPlatform(
      platform,
      uid: 'verified-security-user',
      email: 'securite@ilipresto.fr',
      emailVerified: true,
      providerId: 'password',
    );

    await pumpPage(tester);

    expect(find.text('Sécurité du compte'), findsOneWidget);
    expect(find.text('securite@ilipresto.fr'), findsOneWidget);
    expect(find.text('Email vérifié'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Email vérifié'),
          matching: find.byType(ListTile),
        ),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    expect(find.text('Aucun numéro vérifié'), findsOneWidget);
    expect(find.text('Changer mon email'), findsOneWidget);
    expect(find.text('Changer mon mot de passe'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Supprimer mon compte'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Supprimer mon compte'), findsOneWidget);
  });

  testWidgets('affiche le repli sans session comme email non vérifié',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('Email inconnu'), findsOneWidget);
    expect(find.text('Email non vérifié'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Email non vérifié'),
          matching: find.byType(ListTile),
        ),
        matching: find.byIcon(Icons.warning),
      ),
      findsOneWidget,
    );
    expect(find.text('Aucun numéro vérifié'), findsOneWidget);
  });

  testWidgets('redirige un compte non vérifié vers la vérification email',
      (tester) async {
    final user = _SecurityUserPlatform(
      platform,
      uid: 'unverified-security-user',
      email: 'nonverifie@ilipresto.fr',
      emailVerified: false,
      providerId: 'password',
    );
    platform.user = user;
    final observer = await pumpPage(tester);

    await tester.tap(find.text('Changer mon email'));
    await tester.pump();

    expect(user.reloadCalls, 1);
    expect(
      destinationOf(observer, tester.element(find.byType(AccountSecurityPage))),
      isA<VerifyEmailPage>(),
    );
  });

  testWidgets('ouvre la page de changement d email pour un compte vérifié',
      (tester) async {
    final user = _SecurityUserPlatform(
      platform,
      uid: 'email-security-user',
      email: 'email@ilipresto.fr',
      emailVerified: true,
      providerId: 'password',
    );
    platform.user = user;
    final observer = await pumpPage(tester);

    await tester.tap(find.text('Changer mon email'));
    await tester.pump();

    expect(user.reloadCalls, 1);
    expect(
      destinationOf(observer, tester.element(find.byType(AccountSecurityPage))),
      isA<ChangeEmailPage>(),
    );
  });

  testWidgets('ouvre la page de changement de mot de passe', (tester) async {
    final user = _SecurityUserPlatform(
      platform,
      uid: 'password-security-user',
      email: 'password@ilipresto.fr',
      emailVerified: true,
      providerId: 'password',
    );
    platform.user = user;
    final observer = await pumpPage(tester);

    await tester.tap(find.text('Changer mon mot de passe'));
    await tester.pump();

    expect(user.reloadCalls, 1);
    expect(
      destinationOf(observer, tester.element(find.byType(AccountSecurityPage))),
      isA<ChangePasswordPage>(),
    );
  });

  testWidgets('affiche un téléphone vérifié et son indicateur vert', (
    tester,
  ) async {
    platform.user = _SecurityUserPlatform(
      platform,
      uid: 'phone-security-user',
      email: 'phone@ilipresto.fr',
      emailVerified: true,
      providerId: 'password',
      phoneNumber: '+33612345678',
    );

    await pumpPage(tester);

    expect(find.text('+33612345678'), findsOneWidget);
    expect(find.text('Téléphone vérifié'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Téléphone vérifié'),
          matching: find.byType(ListTile),
        ),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
  });

  testWidgets('ouvre la vérification du téléphone', (tester) async {
    final user = _SecurityUserPlatform(
      platform,
      uid: 'phone-nav-security-user',
      email: 'phone-nav@ilipresto.fr',
      emailVerified: true,
      providerId: 'password',
    );
    platform.user = user;
    final observer = await pumpPage(tester);

    await tester.tap(find.text('Aucun numéro vérifié'));
    await tester.pump();

    expect(
      destinationOf(observer, tester.element(find.byType(AccountSecurityPage))),
      isA<PhoneVerificationPage>(),
    );

    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('ouvre la suppression même avec un email non vérifié',
      (tester) async {
    final user = _SecurityUserPlatform(
      platform,
      uid: 'delete-security-user',
      email: 'delete@ilipresto.fr',
      emailVerified: false,
      providerId: 'password',
    );
    platform.user = user;
    final observer = await pumpPage(tester);

    await tester.scrollUntilVisible(
      find.text('Supprimer mon compte'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pump();

    expect(user.reloadCalls, 0);
    expect(
      destinationOf(observer, tester.element(find.byType(AccountSecurityPage))),
      isA<DeleteAccountPage>(),
    );
  });
}
