// ignore_for_file: depend_on_referenced_packages

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_storage_platform_interface/firebase_storage_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/consult_offers_page.dart';
import 'package:presto_app/pages/home_page.dart';
import 'package:presto_app/widgets/home_bottom_nav_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedOutHomeAuthPlatform extends FirebaseAuthPlatform {
  _SignedOutHomeAuthPlatform() : super(appInstance: null);

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
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(null);
}

class _HomeStoragePlatform extends FirebaseStoragePlatform {
  _HomeStoragePlatform() : super(bucket: 'presto-test.appspot.com');

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

  late FirebaseAuthPlatform originalAuthPlatform;
  late FirebaseStoragePlatform originalStoragePlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: '1:1234567890:web:home-shell-coverage',
          messagingSenderId: '1234567890',
          projectId: 'presto-test',
          storageBucket: 'presto-test.appspot.com',
        ),
      );
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    originalAuthPlatform = FirebaseAuthPlatform.instance;
    originalStoragePlatform = FirebaseStoragePlatform.instance;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FirebaseAuthPlatform.instance = _SignedOutHomeAuthPlatform();
    FirebaseStoragePlatform.instance = _HomeStoragePlatform();
  });

  tearDown(() {
    FirebaseAuthPlatform.instance = originalAuthPlatform;
    FirebaseStoragePlatform.instance = originalStoragePlatform;
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    int initialIndex = 0,
    String? category,
    Key? key,
  }) async {
    tester.view.physicalSize = const Size(1000, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          key: key,
          initialIndex: initialIndex,
          initialConsultCategoryFilter: category,
        ),
      ),
    );
    for (var i = 0; i < 8; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> disposeHomeAndFlushTimers(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    // Public-offer warm-cache requests use deterministic 12 s safety timers.
    // Advance fake time after disposal so no asynchronous timer leaks between
    // widget tests while keeping the production timeout unchanged.
    await tester.pump(const Duration(seconds: 13));
  }

  testWidgets('rend le shell home déconnecté et traverse navigation et lifecycle',
      (tester) async {
    await pumpHome(tester);

    expect(find.text('iliprestō'), findsOneWidget);
    final navItems = find.byType(HomeBottomNavItem);
    expect(navItems, findsNWidgets(5));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    await tester.tap(find.text('Je consulte\nles offres'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ConsultOffersPage), findsOneWidget);

    await disposeHomeAndFlushTimers(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('initialise directement la consultation et réagit à une catégorie',
      (tester) async {
    const key = ValueKey<String>('home-coverage');
    await pumpHome(
      tester,
      key: key,
      initialIndex: 1,
      category: 'Peinture',
    );

    expect(find.byType(ConsultOffersPage), findsOneWidget);
    expect(find.byType(HomeBottomNavItem), findsNWidgets(5));

    await tester.pumpWidget(
      const MaterialApp(
        home: HomePage(
          key: key,
          initialIndex: 1,
          initialConsultCategoryFilter: 'Jardinage',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ConsultOffersPage), findsOneWidget);

    await disposeHomeAndFlushTimers(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hero fallback avance puis le home se dispose proprement',
      (tester) async {
    await pumpHome(tester);

    expect(find.byType(HomePage), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(HomePage), findsOneWidget);

    await disposeHomeAndFlushTimers(tester);
    expect(tester.takeException(), isNull);
  });
}
