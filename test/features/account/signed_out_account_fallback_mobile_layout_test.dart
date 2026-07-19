import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/account/signed_out_account_fallback.dart';

class _SignedOutAuthPlatform extends FirebaseAuthPlatform {
  _SignedOutAuthPlatform() : super(appInstance: null);

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
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _SignedOutAuthPlatform();
  });

  testWidgets('utilise le rendu plein écran sur téléphone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: SignedOutAccountFallback()),
    );
    await tester.pump();

    expect(find.text('Connexion à mon compte'), findsOneWidget);

    final decoratedBoxes = tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    );
    final accountCard = decoratedBoxes.firstWhere((box) {
      final decoration = box.decoration;
      return decoration is BoxDecoration &&
          decoration.border != null &&
          decoration.color == Colors.white;
    });
    final decoration = accountCard.decoration as BoxDecoration;

    expect(decoration.borderRadius, BorderRadius.zero);
    expect(decoration.boxShadow, isEmpty);

    final cardPadding = tester.widgetList<Padding>(find.byType(Padding)).firstWhere(
          (padding) => padding.padding == EdgeInsets.zero,
        );
    expect(cardPadding.padding, EdgeInsets.zero);
  });
}
