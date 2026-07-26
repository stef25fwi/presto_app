import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/hero_slide.dart';
import 'package:presto_app/services/hero_slides_service.dart';

class _EdgeMultiFactorPlatform extends MultiFactorPlatform {
  _EdgeMultiFactorPlatform(super.auth);
}

class _EdgeUserPlatform extends UserPlatform {
  _EdgeUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _EdgeMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'hero-edge-admin',
              email: 'hero-edge@example.test',
              displayName: 'Hero Edge Admin',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime(2026, 7, 26).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );
}

class _EdgeAuthPlatform extends FirebaseAuthPlatform {
  _EdgeAuthPlatform() : super(appInstance: null) {
    user = _EdgeUserPlatform(this);
  }

  late final UserPlatform user;

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

  @override
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(user);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseApp firebaseApp;
  late FakeFirebaseFirestore firestore;
  late HeroSlidesService service;

  HeroSlide slide({
    required String id,
    required int order,
    bool isFirst = false,
    bool isActive = true,
    int durationSeconds = 5,
    String scope = 'global',
    List<String> targetRegions = const <String>[],
  }) {
    return HeroSlide(
      id: id,
      title: 'Slide $id',
      mediaUrl: 'https://cdn.example.test/$id.jpg',
      storagePath: '',
      mediaType: 'image',
      durationSeconds: durationSeconds,
      order: order,
      isActive: isActive,
      isFirst: isFirst,
      createdAt: DateTime.utc(2026, 7, 26),
      updatedAt: DateTime.utc(2026, 7, 26),
      createdBy: 'hero-edge-admin',
      scope: scope,
      targetRegions: targetRegions,
    );
  }

  Map<String, dynamic> data(HeroSlide value) => <String, dynamic>{
        ...value.toJson(),
        'createdAt': null,
        'updatedAt': null,
      };

  setUpAll(() async {
    setupFirebaseCoreMocks();
    FirebaseAuthPlatform.instance = _EdgeAuthPlatform();
    const appName = 'hero-slides-edge-mutations-test';
    try {
      firebaseApp = await Firebase.initializeApp(
        name: appName,
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: '1:1234567890:web:hero-edge-mutations',
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

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = HeroSlidesService(
      firestore: firestore,
      storage: FirebaseStorage.instanceFor(
        app: firebaseApp,
        bucket: 'gs://presto-test.appspot.com',
      ),
      auth: FirebaseAuth.instanceFor(app: firebaseApp),
    );
  });

  test('promeut une slide, déclasse l ancienne et normalise les valeurs',
      () async {
    final previousFirst = slide(id: 'previous', order: 0, isFirst: true);
    final promoted = slide(id: 'promoted', order: 8);
    await firestore
        .collection('heroSlides')
        .doc(previousFirst.id)
        .set(data(previousFirst));
    await firestore
        .collection('heroSlides')
        .doc(promoted.id)
        .set(data(promoted));

    final longTitle = List<String>.filled(90, 'x').join();
    await service.updateSlide(
      promoted,
      title: longTitle,
      durationSeconds: 120,
      order: 2,
      isFirst: true,
      scope: 'unsupported-scope',
      targetRegions: const <String>['GP'],
    );

    final previousData = (await firestore
            .collection('heroSlides')
            .doc(previousFirst.id)
            .get())
        .data()!;
    final promotedData =
        (await firestore.collection('heroSlides').doc(promoted.id).get()).data()!;

    expect(previousData['isFirst'], isFalse);
    expect(promotedData['isFirst'], isTrue);
    expect(promotedData['title'], List<String>.filled(80, 'x').join());
    expect(promotedData['durationSeconds'], 60);
    expect(promotedData['order'], 2);
    expect(promotedData['scope'], 'global');
    expect(promotedData['targetRegions'], <String>['GP']);
  });

  test('désactive la première sans remplaçant actif et utilise les replis',
      () async {
    final current = slide(
      id: 'current',
      order: 0,
      isFirst: true,
      targetRegions: const <String>['MQ'],
    );
    final inactive = slide(id: 'inactive', order: 1, isActive: false);
    await firestore.collection('heroSlides').doc(current.id).set(data(current));
    await firestore.collection('heroSlides').doc(inactive.id).set(data(inactive));

    await service.updateSlide(
      current,
      title: '   ',
      durationSeconds: 1,
      isActive: false,
      isFirst: true,
    );

    final currentData =
        (await firestore.collection('heroSlides').doc(current.id).get()).data()!;
    final inactiveData =
        (await firestore.collection('heroSlides').doc(inactive.id).get()).data()!;

    expect(currentData['title'], 'Slide current');
    expect(currentData['durationSeconds'], 3);
    expect(currentData['isActive'], isFalse);
    expect(currentData['isFirst'], isFalse);
    expect(currentData['scope'], 'global');
    expect(currentData['targetRegions'], <String>['MQ']);
    expect(inactiveData['isFirst'], isFalse);
  });

  test('supprime une première slide sans promouvoir une slide inactive',
      () async {
    final current = slide(id: 'current', order: 0, isFirst: true);
    final inactive = slide(id: 'inactive', order: 1, isActive: false);
    await firestore.collection('heroSlides').doc(current.id).set(data(current));
    await firestore.collection('heroSlides').doc(inactive.id).set(data(inactive));

    await service.deleteSlide(current);

    expect(
      (await firestore.collection('heroSlides').doc(current.id).get()).exists,
      isFalse,
    );
    expect(
      (await firestore.collection('heroSlides').doc(inactive.id).get())[
          'isFirst'],
      isFalse,
    );
  });
}
