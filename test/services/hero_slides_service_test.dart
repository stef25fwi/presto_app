import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/hero_slide.dart';
import 'package:presto_app/services/hero_slides_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HeroMultiFactorPlatform extends MultiFactorPlatform {
  _HeroMultiFactorPlatform(super.auth);
}

class _HeroUserPlatform extends UserPlatform {
  _HeroUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _HeroMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'hero-admin',
              email: 'hero-admin@ilipresto.fr',
              displayName: 'Admin Hero',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp:
                  DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 17).millisecondsSinceEpoch,
            ),
            providerData: <Map<String, dynamic>?>[
              <String, dynamic>{
                'providerId': 'password',
                'uid': 'hero-admin',
                'email': 'hero-admin@ilipresto.fr',
                'displayName': 'Admin Hero',
                'phoneNumber': null,
                'photoURL': null,
                'isAnonymous': false,
                'isEmailVerified': true,
              },
            ],
          ),
        );
}

class _HeroAuthPlatform extends FirebaseAuthPlatform {
  _HeroAuthPlatform() : super(appInstance: null);

  UserPlatform? user;

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

class _TestHeroSlidesService extends HeroSlidesService {
  _TestHeroSlidesService({
    required super.firestore,
    required super.storage,
    required super.auth,
  });

  HeroMediaUploadResult uploadResult = const HeroMediaUploadResult(
    mediaUrl: 'https://cdn.test/hero.webp',
    storagePath: 'hero_slides/generated_hero.webp',
    mediaType: 'image',
  );
  Object? uploadError;
  final List<String> deletedPaths = <String>[];

  @override
  Future<HeroMediaUploadResult> uploadHeroMedia({
    required Uint8List fileBytes,
    required String fileName,
    required String mediaType,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    final error = uploadError;
    if (error != null) throw error;
    onProgress?.call(0.5);
    return uploadResult;
  }

  @override
  Future<void> deleteHeroMedia(String storagePath) async {
    deletedPaths.add(storagePath);
  }
}

Map<String, dynamic> _slideData({
  required String title,
  required String mediaUrl,
  String storagePath = '',
  String mediaType = 'image',
  int durationSeconds = 5,
  int order = 0,
  bool isActive = true,
  bool isFirst = false,
  String scope = 'global',
  List<String> targetRegions = const <String>[],
}) {
  return <String, dynamic>{
    'title': title,
    'mediaUrl': mediaUrl,
    'storagePath': storagePath,
    'mediaType': mediaType,
    'durationSeconds': durationSeconds,
    'order': order,
    'isActive': isActive,
    'isFirst': isFirst,
    'createdAt': Timestamp.fromDate(DateTime.utc(2026, 7, 1)),
    'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 7, 2)),
    'createdBy': 'seed-admin',
    'scope': scope,
    'targetRegions': targetRegions,
  };
}

HeroSlide _slide({
  required String id,
  required String title,
  required String mediaUrl,
  String storagePath = '',
  String mediaType = 'image',
  int durationSeconds = 5,
  int order = 0,
  bool isActive = true,
  bool isFirst = false,
  String scope = 'global',
  List<String> targetRegions = const <String>[],
}) {
  return HeroSlide(
    id: id,
    title: title,
    mediaUrl: mediaUrl,
    storagePath: storagePath,
    mediaType: mediaType,
    durationSeconds: durationSeconds,
    order: order,
    isActive: isActive,
    isFirst: isFirst,
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 2),
    createdBy: 'seed-admin',
    scope: scope,
    targetRegions: targetRegions,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _HeroAuthPlatform authPlatform;
  late FakeFirebaseFirestore firestore;
  late FirebaseStorage storage;
  late _TestHeroSlidesService service;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _HeroAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
    storage = FirebaseStorage.instance;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    firestore = FakeFirebaseFirestore();
    authPlatform.user = _HeroUserPlatform(authPlatform);
    service = _TestHeroSlidesService(
      firestore: firestore,
      storage: storage,
      auth: FirebaseAuth.instance,
    );
  });

  tearDown(() {
    authPlatform.user = null;
  });

  test('charge uniquement les slides actifs et valides depuis le cache',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'hero_slides_cache_v1': jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'cached-active',
          ..._slideData(
            title: 'Actif',
            mediaUrl: 'https://cdn.test/active.webp',
          ),
          'createdAt': '2026-07-01T00:00:00.000Z',
          'updatedAt': '2026-07-02T00:00:00.000Z',
        },
        <String, dynamic>{
          'id': 'cached-inactive',
          ..._slideData(
            title: 'Inactif',
            mediaUrl: 'https://cdn.test/inactive.webp',
            isActive: false,
          ),
        },
        <String, dynamic>{
          'id': 'cached-empty',
          ..._slideData(title: 'Sans média', mediaUrl: ''),
        },
      ]),
    });

    final slides = await service.loadCachedSlides();

    expect(slides.map((slide) => slide.id), <String>['cached-active']);
    expect(slides.single.createdAt, DateTime.utc(2026, 7, 1));

    SharedPreferences.setMockInitialValues(<String, Object>{
      'hero_slides_cache_v1': '{json-invalide',
    });
    expect(await service.loadCachedSlides(), isEmpty);
  });

  test('filtre les slides globaux, régionaux et historiques', () {
    final slides = <HeroSlide>[
      _slide(
        id: 'global',
        title: 'Global',
        mediaUrl: 'https://cdn.test/global.webp',
      ),
      _slide(
        id: 'gp',
        title: 'Guadeloupe',
        mediaUrl: 'https://cdn.test/gp.webp',
        scope: 'regional',
        targetRegions: const <String>['GP'],
      ),
      _slide(
        id: 'mq',
        title: 'Martinique',
        mediaUrl: 'https://cdn.test/mq.webp',
        scope: 'regional',
        targetRegions: const <String>['MQ'],
      ),
      _slide(
        id: 'regional-empty',
        title: 'Sans cible',
        mediaUrl: 'https://cdn.test/empty.webp',
        scope: 'regional',
      ),
      _slide(
        id: 'legacy',
        title: 'Historique',
        mediaUrl: 'https://cdn.test/legacy.webp',
        scope: 'legacy',
      ),
    ];

    expect(
      service.filterSlidesForRegion(slides, 'GP').map((slide) => slide.id),
      <String>['global', 'gp', 'legacy'],
    );
    expect(
      service.filterSlidesForRegion(slides, null).map((slide) => slide.id),
      <String>['global', 'legacy'],
    );
    expect(
      service.filterSlidesForRegion(slides, '').map((slide) => slide.id),
      <String>['global', 'legacy'],
    );
  });

  test('les flux trient, filtrent et alimentent le cache local', () async {
    await firestore.collection('heroSlides').doc('slide-b').set(
          _slideData(
            title: 'B',
            mediaUrl: 'https://cdn.test/b.webp',
            order: 0,
          ),
        );
    await firestore.collection('heroSlides').doc('slide-first').set(
          _slideData(
            title: 'Premier',
            mediaUrl: 'https://cdn.test/first.webp',
            order: 9,
            isFirst: true,
            scope: 'regional',
            targetRegions: const <String>['GP'],
          ),
        );
    await firestore.collection('heroSlides').doc('slide-inactive').set(
          _slideData(
            title: 'Inactif',
            mediaUrl: 'https://cdn.test/inactive.webp',
            order: -1,
            isActive: false,
          ),
        );

    final active = await service.watchActiveSlides().first;
    expect(active.map((slide) => slide.id), <String>['slide-first', 'slide-b']);

    await Future<void>.delayed(Duration.zero);
    final cached = await service.loadCachedSlides();
    expect(cached.map((slide) => slide.id), <String>['slide-first', 'slide-b']);

    final regional = await service.watchSlidesForRegion('GP').first;
    expect(regional.map((slide) => slide.id),
        <String>['slide-first', 'slide-b']);
    final noRegion = await service.watchSlidesForRegion(null).first;
    expect(noRegion.map((slide) => slide.id), <String>['slide-b']);

    final admin = await service.watchAllSlidesForAdmin().first;
    expect(
      admin.map((slide) => slide.id),
      <String>['slide-first', 'slide-inactive', 'slide-b'],
    );
  });

  test('refuse toutes les mutations lorsque l utilisateur est déconnecté',
      () async {
    authPlatform.user = null;
    final slide = _slide(
      id: 'slide-a',
      title: 'A',
      mediaUrl: 'https://cdn.test/a.webp',
    );
    final unauthenticated = isA<FirebaseException>()
        .having((error) => error.code, 'code', 'unauthenticated');

    await expectLater(
      service.addSlide(
        fileBytes: Uint8List.fromList(<int>[1]),
        fileName: 'a.webp',
        mediaType: 'image',
        contentType: 'image/webp',
      ),
      throwsA(unauthenticated),
    );
    await expectLater(service.updateSlide(slide), throwsA(unauthenticated));
    await expectLater(service.deleteSlide(slide), throwsA(unauthenticated));
    await expectLater(
      service.setAsFirstSlide(slide.id),
      throwsA(unauthenticated),
    );
    await expectLater(
      service.reorderSlides(<HeroSlide>[slide]),
      throwsA(unauthenticated),
    );
  });

  test('ajoute un slide normalisé et remplace le premier existant', () async {
    await firestore.collection('heroSlides').doc('old-first').set(
          _slideData(
            title: 'Ancien premier',
            mediaUrl: 'https://cdn.test/old.webp',
            order: 2,
            isFirst: true,
          ),
        );
    await firestore.collection('heroSlides').doc('last').set(
          _slideData(
            title: 'Dernier',
            mediaUrl: 'https://cdn.test/last.webp',
            order: 4,
          ),
        );
    service.uploadResult = const HeroMediaUploadResult(
      mediaUrl: 'https://cdn.test/new.mp4',
      storagePath: 'hero_slides/new.mp4',
      mediaType: 'video',
    );
    final progress = <double>[];

    await service.addSlide(
      fileBytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'Mon clip final.mp4',
      mediaType: ' VIDEO ',
      contentType: 'video/mp4',
      isFirst: true,
      scope: 'regional',
      targetRegions: const <String>['GP'],
      onUploadProgress: progress.add,
    );

    final snapshot = await firestore.collection('heroSlides').get();
    final added = snapshot.docs.singleWhere(
      (doc) => doc.id != 'old-first' && doc.id != 'last',
    );
    final data = added.data();
    expect(data['title'], 'Mon clip final');
    expect(data['mediaType'], 'video');
    expect(data['durationSeconds'], 10);
    expect(data['order'], 5);
    expect(data['isFirst'], isTrue);
    expect(data['createdBy'], 'hero-admin');
    expect(data['scope'], 'regional');
    expect(data['targetRegions'], <String>['GP']);
    expect(progress, <double>[0.5]);
    expect(
      (await firestore.collection('heroSlides').doc('old-first').get())
          .data()!['isFirst'],
      isFalse,
    );
  });

  test('le premier ajout reçoit ordre zéro, titre borné et statut premier',
      () async {
    final longTitle = List<String>.filled(90, 'x').join();

    await service.addSlide(
      fileBytes: Uint8List.fromList(<int>[1]),
      fileName: 'image.webp',
      mediaType: 'inconnu',
      contentType: 'image/webp',
      title: '  $longTitle  ',
      durationSeconds: 120,
    );

    final added = (await firestore.collection('heroSlides').get()).docs.single;
    expect(added.data()['title'], hasLength(80));
    expect(added.data()['mediaType'], 'image');
    expect(added.data()['durationSeconds'], 60);
    expect(added.data()['order'], 0);
    expect(added.data()['isFirst'], isTrue);
    expect(added.data()['scope'], 'global');
  });

  test('met à jour les métadonnées et choisit un premier de remplacement',
      () async {
    final current = _slide(
      id: 'current',
      title: 'Actuel',
      mediaUrl: 'https://cdn.test/current.webp',
      storagePath: 'hero_slides/current.webp',
      order: 1,
      isFirst: true,
    );
    await firestore.collection('heroSlides').doc(current.id).set(
          _slideData(
            title: current.title,
            mediaUrl: current.mediaUrl,
            storagePath: current.storagePath,
            order: current.order,
            isFirst: true,
          ),
        );
    await firestore.collection('heroSlides').doc('replacement').set(
          _slideData(
            title: 'Remplacement',
            mediaUrl: 'https://cdn.test/replacement.webp',
            order: 5,
          ),
        );
    final longTitle = List<String>.filled(90, 'T').join();

    await service.updateSlide(
      current,
      title: longTitle,
      durationSeconds: 1,
      order: 8,
      isActive: false,
      isFirst: false,
      scope: 'invalide',
      targetRegions: const <String>['MQ'],
    );

    final updated =
        (await firestore.collection('heroSlides').doc('current').get()).data()!;
    expect(updated['title'], hasLength(80));
    expect(updated['durationSeconds'], 3);
    expect(updated['order'], 8);
    expect(updated['isActive'], isFalse);
    expect(updated['isFirst'], isFalse);
    expect(updated['scope'], 'global');
    expect(updated['targetRegions'], <String>['MQ']);
    expect(
      (await firestore.collection('heroSlides').doc('replacement').get())
          .data()!['isFirst'],
      isTrue,
    );
  });

  test('remplace le média puis nettoie l ancien fichier', () async {
    final current = _slide(
      id: 'replace-media',
      title: 'Image',
      mediaUrl: 'https://cdn.test/old.webp',
      storagePath: 'hero_slides/old.webp',
      isFirst: false,
    );
    await firestore.collection('heroSlides').doc(current.id).set(
          _slideData(
            title: current.title,
            mediaUrl: current.mediaUrl,
            storagePath: current.storagePath,
          ),
        );
    service.uploadResult = const HeroMediaUploadResult(
      mediaUrl: 'https://cdn.test/replacement.mp4',
      storagePath: 'hero_slides/replacement.mp4',
      mediaType: 'video',
    );

    await service.updateSlide(
      current,
      replacementFileBytes: Uint8List.fromList(<int>[9, 8, 7]),
      replacementFileName: 'replacement.mp4',
      replacementMediaType: 'video',
      replacementContentType: 'video/mp4',
      durationSeconds: 99,
    );

    final updated = (await firestore
            .collection('heroSlides')
            .doc('replace-media')
            .get())
        .data()!;
    expect(updated['mediaUrl'], 'https://cdn.test/replacement.mp4');
    expect(updated['storagePath'], 'hero_slides/replacement.mp4');
    expect(updated['mediaType'], 'video');
    expect(updated['durationSeconds'], 60);
    expect(service.deletedPaths, <String>['hero_slides/old.webp']);
  });

  test('supprime, réattribue le premier, réordonne et force un premier',
      () async {
    final first = _slide(
      id: 'first',
      title: 'Premier',
      mediaUrl: 'https://cdn.test/first.webp',
      storagePath: 'hero_slides/first.webp',
      order: 0,
      isFirst: true,
    );
    final second = _slide(
      id: 'second',
      title: 'Second',
      mediaUrl: 'https://cdn.test/second.webp',
      order: 4,
    );
    final inactive = _slide(
      id: 'inactive',
      title: 'Inactif',
      mediaUrl: 'https://cdn.test/inactive.webp',
      order: 1,
      isActive: false,
    );
    for (final slide in <HeroSlide>[first, second, inactive]) {
      await firestore.collection('heroSlides').doc(slide.id).set(
            _slideData(
              title: slide.title,
              mediaUrl: slide.mediaUrl,
              storagePath: slide.storagePath,
              order: slide.order,
              isActive: slide.isActive,
              isFirst: slide.isFirst,
            ),
          );
    }

    await service.deleteSlide(first);
    expect(
      (await firestore.collection('heroSlides').doc('first').get()).exists,
      isFalse,
    );
    expect(
      (await firestore.collection('heroSlides').doc('second').get())
          .data()!['isFirst'],
      isTrue,
    );
    expect(service.deletedPaths, <String>['hero_slides/first.webp']);

    await service.setAsFirstSlide('inactive');
    expect(
      (await firestore.collection('heroSlides').doc('inactive').get())
          .data()!['isFirst'],
      isTrue,
    );
    expect(
      (await firestore.collection('heroSlides').doc('second').get())
          .data()!['isFirst'],
      isFalse,
    );

    await service.reorderSlides(<HeroSlide>[inactive, second]);
    expect(
      (await firestore.collection('heroSlides').doc('inactive').get())
          .data()!['order'],
      0,
    );
    expect(
      (await firestore.collection('heroSlides').doc('second').get())
          .data()!['order'],
      1,
    );
  });

  test('valide les entrées média avant tout appel Storage', () async {
    final plainService = HeroSlidesService(
      firestore: firestore,
      storage: storage,
      auth: FirebaseAuth.instance,
    );

    await expectLater(
      plainService.uploadHeroMedia(
        fileBytes: Uint8List(0),
        fileName: 'empty.webp',
        mediaType: 'image',
        contentType: 'image/webp',
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      plainService.uploadHeroMedia(
        fileBytes: Uint8List.fromList(<int>[1]),
        fileName: '   ',
        mediaType: 'image',
        contentType: 'image/webp',
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(plainService.deleteHeroMedia('   '), completes);
  });

  test('rejette un résultat d upload incomplet sans écrire Firestore',
      () async {
    service.uploadResult = const HeroMediaUploadResult(
      mediaUrl: '',
      storagePath: 'outside/file.webp',
      mediaType: 'image',
    );

    await expectLater(
      service.addSlide(
        fileBytes: Uint8List.fromList(<int>[1]),
        fileName: 'bad.webp',
        mediaType: 'image',
        contentType: 'image/webp',
      ),
      throwsA(isA<StateError>()),
    );
    expect((await firestore.collection('heroSlides').get()).docs, isEmpty);
  });
}
