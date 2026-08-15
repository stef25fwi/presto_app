import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/account/account_security_page.dart';
import 'package:presto_app/pages/account_page.dart';
import 'package:presto_app/pages/legal_info_page.dart';
import 'package:presto_app/pages/user_offers_section.dart';
import 'package:presto_app/widgets/account_profile_sections.dart';

class _AccountActionsMultiFactorPlatform extends MultiFactorPlatform {
  _AccountActionsMultiFactorPlatform(super.auth);
}

class _AccountActionsUserPlatform extends UserPlatform {
  _AccountActionsUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _AccountActionsMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'account-actions-user',
              email: 'account-actions@ilipresto.fr',
              displayName: 'Compte Actions',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp: DateTime(2026, 7, 1).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime(2026, 8, 15).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[
              <String, dynamic>{
                'providerId': 'password',
                'uid': 'account-actions-user',
                'email': 'account-actions@ilipresto.fr',
                'displayName': 'Compte Actions',
                'phoneNumber': '+590690000000',
                'photoURL': null,
                'isAnonymous': false,
                'isEmailVerified': true,
              },
            ],
          ),
        );
}

class _AccountActionsAuthPlatform extends FirebaseAuthPlatform {
  _AccountActionsAuthPlatform() : super(appInstance: null) {
    user = _AccountActionsUserPlatform(this);
  }

  late final UserPlatform user;
  final StreamController<UserPlatform?> _authController =
      StreamController<UserPlatform?>.broadcast();
  final StreamController<UserPlatform?> _idTokenController =
      StreamController<UserPlatform?>.broadcast();
  final StreamController<UserPlatform?> _userController =
      StreamController<UserPlatform?>.broadcast();

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
  Stream<UserPlatform?> authStateChanges() => _authController.stream;

  @override
  Stream<UserPlatform?> idTokenChanges() => _idTokenController.stream;

  @override
  Stream<UserPlatform?> userChanges() => _userController.stream;

  bool get hasIdTokenListener => _idTokenController.hasListener;

  void emitSignedIn() => _idTokenController.add(user);

  Future<void> disposeControllers() async {
    await _authController.close();
    await _idTokenController.close();
    await _userController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AccountActionsAuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _AccountActionsAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  tearDownAll(() async {
    await authPlatform.disposeControllers();
  });

  Future<void> pumpConnectedAccount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AccountPage()));
    for (var frame = 0; frame < 20 && !authPlatform.hasIdTokenListener; frame++) {
      await tester.pump();
    }
    expect(authPlatform.hasIdTokenListener, isTrue);

    authPlatform.emitSignedIn();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('shell connecté ouvre profil, annonces, favoris et routes locales',
      (tester) async {
    await pumpConnectedAccount(tester);

    expect(find.text('Mon compte iliprestō'), findsOneWidget);
    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Mes alertes "Nouvelle annonce"'), findsOneWidget);
    expect(find.text('Gérer mes annonces'), findsOneWidget);
    expect(find.text('Mes annonces favorites'), findsOneWidget);
    expect(find.text('Sécurité du compte'), findsOneWidget);
    expect(find.text('Mentions légales / CGU'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);

    await tester.tap(find.text('Mon profil'));
    await tester.pump();
    expect(find.byType(AccountProfileFormSection), findsOneWidget);

    final edit = find.text('Modifier mon profil');
    if (edit.evaluate().isNotEmpty) {
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pump();
      expect(find.text('Enregistrer mon profil'), findsOneWidget);

      final pseudo = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Pseudo',
      );
      expect(pseudo, findsOneWidget);
      await tester.enterText(pseudo, '');
      await tester.tap(find.text('Enregistrer mon profil'));
      await tester.pump();
      expect(find.text('Le pseudo est obligatoire'), findsOneWidget);
    }

    await tester.tap(find.text('Gérer mes annonces'));
    await tester.pump();
    expect(find.byType(UserOffersSection), findsOneWidget);
    await tester.tap(find.text('Gérer mes annonces'));
    await tester.pump();
    expect(find.byType(UserOffersSection), findsNothing);

    await tester.tap(find.text('Mes annonces favorites'));
    await tester.pump();
    expect(find.byType(FavoriteOffersSection), findsOneWidget);
    await tester.tap(find.text('Mes annonces favorites'));
    await tester.pump();
    expect(find.byType(FavoriteOffersSection), findsNothing);

    final security = find.text('Sécurité du compte');
    await tester.ensureVisible(security);
    await tester.tap(security);
    await tester.pump();
    expect(find.byType(AccountSecurityPage), findsOneWidget);
    Navigator.of(tester.element(find.byType(AccountSecurityPage))).pop();
    await tester.pump();

    final legal = find.text('Mentions légales / CGU');
    await tester.ensureVisible(legal);
    await tester.tap(legal);
    await tester.pump();
    expect(find.byType(LegalInfoPage), findsOneWidget);
    Navigator.of(tester.element(find.byType(LegalInfoPage))).pop();
    await tester.pump();

    await tester.pump(const Duration(seconds: 20));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 20));
    expect(tester.takeException(), isNull);
  });
}
