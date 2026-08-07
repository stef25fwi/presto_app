import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/entrepreneur_toolbox_page.dart';
import 'package:presto_app/pages/toolbox_je_me_lance_page.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _FakeAuthPlatform();
  });

  testWidgets(
    'EntrepreneurToolboxPage délègue au parcours ToolboxJeMeLancePage',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: EntrepreneurToolboxPage()),
      );
      await tester.pump();

      expect(find.byType(EntrepreneurToolboxPage), findsOneWidget);
      expect(find.byType(ToolboxJeMeLancePage), findsOneWidget);
    },
  );
}
