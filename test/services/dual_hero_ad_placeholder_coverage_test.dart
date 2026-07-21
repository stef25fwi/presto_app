import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/hero_slide.dart';
import 'package:presto_app/services/ad_placeholder_image_service.dart';
import 'package:presto_app/services/hero_slides_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseApp firebaseApp;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    const appName = 'dual-coverage-service-test';
    try {
      firebaseApp = await Firebase.initializeApp(
        name: appName,
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: '1:1234567890:web:dual-coverage',
          messagingSenderId: '1234567890',
          projectId: 'presto-test',
          storageBucket: 'presto-test.appspot.com',
        ),
      );
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
      firebaseApp = Firebase.app(appName);
    }
  });

  HeroSlidesService heroService() {
    return HeroSlidesService(
      firestore: FakeFirebaseFirestore(),
      storage: FirebaseStorage.instanceFor(
        app: firebaseApp,
        bucket: 'gs://presto-test.appspot.com',
      ),
      auth: FirebaseAuth.instanceFor(app: firebaseApp),
    );
  }

  HeroSlide slide({
    required String id,
    required String scope,
    List<String> targetRegions = const <String>[],
  }) {
    return HeroSlide(
      id: id,
      title: id,
      mediaUrl: 'https://cdn.test/$id.jpg',
      storagePath: 'hero_slides/$id.jpg',
      mediaType: 'image',
      durationSeconds: 5,
      order: 0,
      isActive: true,
      isFirst: false,
      createdAt: DateTime.utc(2026, 7, 21),
      updatedAt: DateTime.utc(2026, 7, 21),
      createdBy: 'admin',
      scope: scope,
      targetRegions: targetRegions,
    );
  }

  test('AdPlaceholderImage.fromDoc normalise les valeurs absentes', () async {
    final firestore = FakeFirebaseFirestore();
    final ref = firestore.collection('ad_placeholder_images').doc('empty');
    await ref.set(<String, dynamic>{});

    final image = AdPlaceholderImage.fromDoc(await ref.get());

    expect(image.id, 'empty');
    expect(image.imageUrl, isEmpty);
    expect(image.storagePath, isEmpty);
    expect(image.isVisible, isFalse);
    expect(image.target, 'consult_offers');
    expect(image.sortOrder, 0);
    expect(image.title, isNull);
    expect(image.description, isNull);
    expect(image.linkUrl, isNull);
    expect(image.createdAt, isNull);
    expect(image.updatedAt, isNull);
  });

  test('AdPlaceholderImage.fromDoc conserve les métadonnées valides', () async {
    final firestore = FakeFirebaseFirestore();
    final createdAt = Timestamp.fromDate(DateTime.utc(2026, 7, 20));
    final updatedAt = Timestamp.fromDate(DateTime.utc(2026, 7, 21));
    final ref = firestore.collection('ad_placeholder_images').doc('hero-ad');
    await ref.set(<String, dynamic>{
      'imageUrl': 'https://cdn.test/ad.webp',
      'storagePath': 'ad_placeholders/home/ad.webp',
      'isVisible': true,
      'target': 'home',
      'sortOrder': 42,
      'title': 'Carnaval',
      'description': 'Découvrir les offres',
      'linkUrl': 'https://ilipresto.fr/offres',
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    });

    final image = AdPlaceholderImage.fromDoc(await ref.get());

    expect(image.imageUrl, endsWith('ad.webp'));
    expect(image.storagePath, startsWith('ad_placeholders/'));
    expect(image.isVisible, isTrue);
    expect(image.target, 'home');
    expect(image.sortOrder, 42);
    expect(image.title, 'Carnaval');
    expect(image.description, 'Découvrir les offres');
    expect(image.linkUrl, contains('ilipresto.fr'));
    expect(image.createdAt, createdAt);
    expect(image.updatedAt, updatedAt);
  });

  test('loadCachedSlides rejette une structure JSON qui n est pas une liste',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'hero_slides_cache_v1': jsonEncode(<String, dynamic>{'id': 'invalid'}),
    });

    expect(await heroService().loadCachedSlides(), isEmpty);
  });

  test('filterSlidesForRegion traite deux régions dans la même phase', () {
    final service = heroService();
    final slides = <HeroSlide>[
      slide(id: 'global', scope: 'global'),
      slide(id: 'gp', scope: 'regional', targetRegions: const <String>['GP']),
      slide(id: 'mq', scope: 'regional', targetRegions: const <String>['MQ']),
      slide(id: 'legacy', scope: 'legacy'),
    ];

    expect(
      service.filterSlidesForRegion(slides, 'GP').map((entry) => entry.id),
      <String>['global', 'gp', 'legacy'],
    );
    expect(
      service.filterSlidesForRegion(slides, 'MQ').map((entry) => entry.id),
      <String>['global', 'mq', 'legacy'],
    );
  });
}
