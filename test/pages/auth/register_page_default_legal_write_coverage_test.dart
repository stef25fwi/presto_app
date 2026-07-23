import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/operating_mode/app_operating_mode.dart';
import 'package:presto_app/pages/auth/register_page.dart';

class _LegalWriteMultiFactorPlatform extends MultiFactorPlatform {
  _LegalWriteMultiFactorPlatform(super.auth);
}

class _LegalWriteUserPlatform extends UserPlatform {
  _LegalWriteUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _LegalWriteMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'register-legal-write',
              email: 'legal-write@ilipresto.fr',
              displayName: 'Legal write',
              isAnonymous: false,
              isEmailVerified: false,
              creationTimestamp:
                  DateTime(2026, 7, 23).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 23).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );
}

class _LegalWriteAuthPlatform extends FirebaseAuthPlatform {
  _LegalWriteAuthPlatform() : super(appInstance: null);

  late final UserPlatform user = _LegalWriteUserPlatform(this);

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _LegalWriteAuthPlatform();
  });

  Finder field(String label) {
    final decorator = find.byWidgetPredicate(
      (widget) =>
          widget is InputDecorator && widget.decoration.labelText == label,
    );
    return find.descendant(of: decorator, matching: find.byType(EditableText));
  }

  testWidgets('écrit la preuve juridique avec le service par défaut injectable',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final firestore = FakeFirebaseFirestore();
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPage(
          registerWithEmail: ({
            required email,
            required password,
            required displayName,
            required fullName,
            required firstName,
            required lastName,
            required pseudo,
          }) async {},
          successPageBuilder: (_) => const Scaffold(body: Text('succès légal')),
          operatingModeServiceFactory: () => AppOperatingModeService(
            firestore: firestore,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(field('Nom *'), 'Durand');
    await tester.enterText(field('Prénom *'), 'Lina');
    await tester.enterText(field('Pseudo'), 'Lina');
    await tester.enterText(field('Email'), 'lina@example.com');
    await tester.enterText(field('Mot de passe'), 'Password1');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Créer mon compte'));

    for (var frame = 0;
        frame < 20 && find.text('succès légal').evaluate().isEmpty;
        frame += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final user = await firestore.collection('users').doc('register-legal-write').get();
    final acceptance = Map<String, dynamic>.from(
      user.data()!['legalAcceptance'] as Map,
    );
    expect(acceptance['operatingMode'], 'free_beta');
    expect(acceptance['legalVersion'], 'beta-free-v1');
    expect(acceptance['cguVersion'], 'cgu-beta-free-v1');
    expect(acceptance['privacyVersion'], 'privacy-beta-free-v1');
    expect(acceptance['source'], 'registration');
    expect(find.text('succès légal'), findsOneWidget);
  });
}
