// ignore_for_file: depend_on_referenced_packages

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_storage_platform_interface/firebase_storage_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/home_page.dart';
import 'package:presto_app/pages/publish_offer_page.dart';
import 'package:presto_app/widgets/ai_publish_control.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedOutAuth extends FirebaseAuthPlatform {
  _SignedOutAuth() : super(appInstance: null);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream.value(null);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream.value(null);

  @override
  Stream<UserPlatform?> userChanges() => Stream.value(null);
}

class _TestStorage extends FirebaseStoragePlatform {
  _TestStorage() : super(bucket: 'presto-test.appspot.com');

  @override
  FirebaseStoragePlatform delegateFor({
    required FirebaseApp app,
    required String bucket,
  }) => this;

  @override
  int get maxDownloadRetryTime => 0;

  @override
  int get maxOperationRetryTime => 0;

  @override
  int get maxUploadRetryTime => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('Publier garde la description après un aller-retour Accueil',
      (tester) async {
    final previousAuth = FirebaseAuthPlatform.instance;
    final previousStorage = FirebaseStoragePlatform.instance;
    FirebaseAuthPlatform.instance = _SignedOutAuth();
    FirebaseStoragePlatform.instance = _TestStorage();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(() {
      FirebaseAuthPlatform.instance = previousAuth;
      FirebaseStoragePlatform.instance = previousStorage;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(PublishOfferPage, skipOffstage: false), findsNothing);

    await tester.tap(find.text('Publier\nune offre'));
    await tester.pump(const Duration(milliseconds: 300));
    tester.widget<AiPublishControl>(find.byType(AiPublishControl)).onSelectText();
    await tester.pump(const Duration(milliseconds: 300));

    final description = find.byWidgetPredicate(
      (widget) => widget is TextField && (widget.maxLines ?? 1) > 1,
    );
    // Selecting text primes a read-only preview; the user taps it to edit.
    await tester.tap(description);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<TextField>(description).readOnly, isFalse);
    final draftController = tester.widget<TextField>(description).controller;
    final publishState = tester.state(find.byType(PublishOfferPage));
    const draft = 'Recherche jardinier à Baie-Mahault pour entretenir un jardin.';
    await tester.enterText(description, draft);
    await tester.pump();
    expect(draftController?.text, draft);

    await tester.tap(find.text('Accueil'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PublishOfferPage), findsNothing);
    expect(draftController?.text, draft);
    expect(
      TickerMode.of(tester.element(
        find.byType(PublishOfferPage, skipOffstage: false),
      )),
      isFalse,
    );

    await tester.tap(find.text('Publier\nune offre'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.state(find.byType(PublishOfferPage)), same(publishState));
    expect(
      tester.widget<TextField>(description).controller,
      same(draftController),
    );
    expect(tester.widget<TextField>(description).controller?.text, draft);
    expect(tester.widget<TextField>(description).enabled, isNot(false));
    expect(
      TickerMode.of(tester.element(find.byType(PublishOfferPage))),
      isTrue,
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 13));
    expect(tester.takeException(), isNull);
  });
}
