// The platform interface is used only to provide a deterministic Firebase
// Storage delegate while exercising the real Admin Hero page bootstrap.
// ignore_for_file: depend_on_referenced_packages

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_storage_platform_interface/firebase_storage_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin_hero_slides_page.dart';

class _AdminHeroStoragePlatform extends FirebaseStoragePlatform {
  _AdminHeroStoragePlatform() : super(bucket: 'presto-test.appspot.com');

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

  late FirebaseStoragePlatform originalStoragePlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();

    // Some test bootstraps can already expose a mocked default application.
    // Recreating it would raise [core/duplicate-app], so initialization must
    // remain idempotent. Firebase.apps.isEmpty is not a reliable guard here
    // because test isolates are reused across files, so catch the exception
    // instead of pre-checking, the same idiom other suites in this repo use.
    // A default app left behind by another test file may have no storage
    // bucket configured (Firebase forbids deleting/reconfiguring "[DEFAULT]"
    // once created), so HeroSlidesService falls back to the project's real
    // bucket in that case instead of this test trying to fix it here.
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: '1:1234567890:web:admin-hero-permanent',
          messagingSenderId: '1234567890',
          projectId: 'presto-test',
          storageBucket: 'presto-test.appspot.com',
        ),
      );
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') {
        rethrow;
      }
    }

    originalStoragePlatform = FirebaseStoragePlatform.instance;
  });

  setUp(() {
    FirebaseStoragePlatform.instance = _AdminHeroStoragePlatform();
  });

  tearDown(() {
    FirebaseStoragePlatform.instance = originalStoragePlatform;
  });

  Future<void> pumpAdminHero(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AdminHeroSlidesPage()),
    );
    await tester.pump();
  }

  testWidgets('affiche la structure Admin Hero au démarrage', (tester) async {
    await pumpAdminHero(tester, size: const Size(1000, 1800));

    expect(find.text('Gestion du Hero'), findsOneWidget);
    expect(find.byTooltip('Ajouter un slide'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
          find
              .text('Impossible de charger les slides Hero pour le moment.')
              .evaluate()
              .isNotEmpty,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reste stable sur une largeur mobile après plusieurs frames',
      (tester) async {
    await pumpAdminHero(tester, size: const Size(430, 1200));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Gestion du Hero'), findsOneWidget);
    expect(find.byTooltip('Ajouter un slide'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
