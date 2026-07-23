import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/operating_mode/app_operating_mode.dart';
import 'package:presto_app/pages/auth/register_page.dart';

class _ThrowingCurrentUserAuthPlatform extends FirebaseAuthPlatform {
  _ThrowingCurrentUserAuthPlatform() : super(appInstance: null);

  var currentUserReads = 0;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser {
    currentUserReads += 1;
    throw StateError('auth temporarily unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ThrowingCurrentUserAuthPlatform platform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _ThrowingCurrentUserAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  Finder field(String label) {
    final decorator = find.byWidgetPredicate(
      (widget) =>
          widget is InputDecorator && widget.decoration.labelText == label,
    );
    return find.descendant(of: decorator, matching: find.byType(EditableText));
  }

  testWidgets('utilise les valeurs juridiques embarquées si Firebase échoue',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var registrationCalls = 0;
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
          }) async {
            registrationCalls += 1;
          },
          successPageBuilder: (_) => const Scaffold(body: Text('succès')),
          operatingModeServiceFactory: () => AppOperatingModeService(
            firestore: FakeFirebaseFirestore(),
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
        frame < 20 && find.text('succès').evaluate().isEmpty;
        frame += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(registrationCalls, 1);
    expect(platform.currentUserReads, greaterThan(0));
    expect(find.text('succès'), findsOneWidget);
  });
}
