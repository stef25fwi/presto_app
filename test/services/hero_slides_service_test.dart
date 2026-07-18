import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/hero_slide.dart';
import 'package:presto_app/services/hero_slides_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: '1:1234567890:web:test',
        messagingSenderId: '1234567890',
        projectId: 'presto-test',
        storageBucket: 'presto-test.appspot.com',
      ),
    );
  });

  late FakeFirebaseFirestore firestore;
  late HeroSlidesService service;

  HeroSlide slide({
    required String id,
    int order = 0,
    bool isActive = true,
    bool isFirst = false,
    String scope = 'global',
    List<String> targetRegions = const <String>[],
    String mediaUrl = 'https://cdn.example.test/hero.jpg',
  }) {
    return HeroSlide(
      id: id,
      title: 'Slide $id',
      mediaUrl: mediaUrl,
      storagePath: 'hero_slides/$id.jpg',
      mediaType: 'image',
      durationSeconds: 5,
      order: order,
      isActive: isActive,
      isFirst: isFirst,
      createdAt: DateTime.utc(2026, 7, 18),
      updatedAt: DateTime.utc(2026, 7, 18),
      createdBy: 'admin-1',
      scope: scope,
      targetRegions: targetRegions,
    );
  }

  Map<String, dynamic> slideData({
    required String title,
    required int order,
    bool isActive = true,
    bool isFirst = false,
    String scope = 'global',
    List<String> targetRegions = const <String>[],
    String mediaUrl = 'https://cdn.example.test/hero.jpg',
  }) {
    return <String, dynamic>{
      'title': title,
      'mediaUrl': mediaUrl,
      'storagePath': 'hero_slides/$title.jpg',
      'mediaType': 'image',
      'durationSeconds': 5,
      'order': order,
      'isActive': isActive,
      'isFirst': isFirst,
      'createdBy': 'admin-1',
      'scope': scope,
      'targetRegions': targetRegions,
    };
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    firestore = FakeFirebaseFirestore();
    service = HeroSlidesService(
      firestore: firestore,
      storage: FirebaseStorage.instance,
      auth: FirebaseAuth.instance,
    );
  });

  test('loadCachedSlides retourne une liste vide sans cache', () async {
    expect(await service.loadCachedSlides(), isEmpty);
  });

  test('loadCachedSlides filtre les entrées inactives et sans média', () async {
    final active = slide(id: 'active').toJson();
    final inactive = slide(id: 'inactive', isActive: false).toJson();
    final withoutMedia = slide(id: 'empty', mediaUrl: '').toJson();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'hero_slides_cache_v1': jsonEncode(<Map<String, dynamic>>[
        active,
        inactive,
        withoutMedia,
      ]),
    });

    final cached = await service.loadCachedSlides();

    expect(cached.map((entry) => entry.id), <String>['active']);
  });

  test('loadCachedSlides ignore un cache JSON corrompu', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'hero_slides_cache_v1': '{not-json',
    });

    expect(await service.loadCachedSlides(), isEmpty);
  });

  test('filterSlidesForRegion conserve global, régional ciblé et legacy', () {
    final slides = <HeroSlide>[
      slide(id: 'global'),
      slide(id: 'gp', scope: 'regional', targetRegions: const <String>['GP']),
      slide(id: 'mq', scope: 'regional', targetRegions: const <String>['MQ']),
      slide(id: 'empty', scope: 'regional'),
      slide(id: 'legacy', scope: 'legacy'),
    ];

    expect(
      service.filterSlidesForRegion(slides, 'GP').map((entry) => entry.id),
      <String>['global', 'gp', 'legacy'],
    );
    expect(
      service.filterSlidesForRegion(slides, null).map((entry) => entry.id),
      <String>['global', 'legacy'],
    );
    expect(
      service.filterSlidesForRegion(slides, '').map((entry) => entry.id),
      <String>['global', 'legacy'],
    );
  });

  test('watchActiveSlides filtre puis trie les documents Firestore', () async {
    await firestore.collection('heroSlides').doc('later').set(
          slideData(title: 'later', order: 8),
        );
    await firestore.collection('heroSlides').doc('first').set(
          slideData(title: 'first', order: 99, isFirst: true),
        );
    await firestore.collection('heroSlides').doc('middle').set(
          slideData(title: 'middle', order: 3),
        );
    await firestore.collection('heroSlides').doc('inactive').set(
          slideData(title: 'inactive', order: 0, isActive: false),
        );

    final result = await service.watchActiveSlides().first;

    expect(
      result.map((entry) => entry.id),
      <String>['first', 'middle', 'later'],
    );
  });

  test('watchSlidesForRegion applique le ciblage régional au flux actif', () async {
    await firestore.collection('heroSlides').doc('global').set(
          slideData(title: 'global', order: 0),
        );
    await firestore.collection('heroSlides').doc('gp').set(
          slideData(
            title: 'gp',
            order: 1,
            scope: 'regional',
            targetRegions: const <String>['GP'],
          ),
        );
    await firestore.collection('heroSlides').doc('mq').set(
          slideData(
            title: 'mq',
            order: 2,
            scope: 'regional',
            targetRegions: const <String>['MQ'],
          ),
        );

    final gp = await service.watchSlidesForRegion('GP').first;
    final noRegion = await service.watchSlidesForRegion(null).first;

    expect(gp.map((entry) => entry.id), <String>['global', 'gp']);
    expect(noRegion.map((entry) => entry.id), <String>['global']);
  });

  test('watchAllSlidesForAdmin inclut les inactifs et respecte le tri', () async {
    await firestore.collection('heroSlides').doc('inactive').set(
          slideData(title: 'inactive', order: 2, isActive: false),
        );
    await firestore.collection('heroSlides').doc('active').set(
          slideData(title: 'active', order: 1),
        );

    final result = await service.watchAllSlidesForAdmin().first;

    expect(result.map((entry) => entry.id), <String>['active', 'inactive']);
  });

  test('les mutations administrateur refusent une session absente', () async {
    final existing = slide(id: 'existing');

    Future<void> expectUnauthenticated(Future<void> action) async {
      await expectLater(
        action,
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'unauthenticated',
          ),
        ),
      );
    }

    await expectUnauthenticated(
      service.addSlide(
        fileBytes: Uint8List.fromList(<int>[1]),
        fileName: 'hero.jpg',
        mediaType: 'image',
        contentType: 'image/jpeg',
      ),
    );
    await expectUnauthenticated(service.updateSlide(existing));
    await expectUnauthenticated(service.deleteSlide(existing));
    await expectUnauthenticated(service.setAsFirstSlide(existing.id));
    await expectUnauthenticated(service.reorderSlides(<HeroSlide>[existing]));
  });

  test('uploadHeroMedia valide le fichier avant tout accès Storage', () async {
    await expectLater(
      service.uploadHeroMedia(
        fileBytes: Uint8List(0),
        fileName: 'hero.jpg',
        mediaType: 'image',
        contentType: 'image/jpeg',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Le fichier sélectionné est vide.',
        ),
      ),
    );

    await expectLater(
      service.uploadHeroMedia(
        fileBytes: Uint8List.fromList(<int>[1]),
        fileName: '   ',
        mediaType: 'video',
        contentType: 'video/mp4',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('deleteHeroMedia ignore un chemin vide', () async {
    await service.deleteHeroMedia('   ');
  });

  test('HeroMediaUploadResult conserve les métadonnées normalisées', () {
    const result = HeroMediaUploadResult(
      mediaUrl: 'https://cdn.example.test/file.mp4',
      storagePath: 'hero_slides/file.mp4',
      mediaType: 'video',
    );

    expect(result.mediaUrl, contains('file.mp4'));
    expect(result.storagePath, startsWith('hero_slides/'));
    expect(result.mediaType, 'video');
  });
}
