import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/hero_slide.dart';
import 'package:presto_app/services/hero_slides_service.dart';

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
              uid: 'admin-hero',
              email: 'admin@example.test',
              displayName: 'Admin Hero',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp:
                  DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 18).millisecondsSinceEpoch,
            ),
            providerData: <Map<String, dynamic>?>[
              <String, dynamic>{
                'providerId': 'password',
                'uid': 'admin-hero',
                'email': 'admin@example.test',
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
  _HeroAuthPlatform() : super(appInstance: null) {
    user = _HeroUserPlatform(this);
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
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.value(user);

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
    String storagePath = '',
  }) {
    return HeroSlide(
      id: id,
      title: 'Slide $id',
      mediaUrl: 'https://cdn.example.test/$id.jpg',
      storagePath: storagePath,
      mediaType: 'image',
      durationSeconds: 5,
      order: order,
      isActive: isActive,
      isFirst: isFirst,
      createdAt: DateTime.utc(2026, 7, 18),
      updatedAt: DateTime.utc(2026, 7, 18),
      createdBy: 'admin-hero',
      scope: 'global',
      targetRegions: const <String>[],
    );
  }

  Map<String, dynamic> data(HeroSlide value) => <String, dynamic>{
        ...value.toJson(),
        'createdAt': null,
        'updatedAt': null,
      };

  setUpAll(() async {
    setupFirebaseCoreMocks();
    FirebaseAuthPlatform.instance = _HeroAuthPlatform();
    const appName = 'hero-slides-mutations-test';
    try {
      firebaseApp = await Firebase.initializeApp(
        name: appName,
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: '1:1234567890:web:hero-mutations',
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

  test('setAsFirstSlide bascule atomiquement la première slide', () async {
    final first = slide(id: 'first', order: 0, isFirst: true);
    final second = slide(id: 'second', order: 1);
    await firestore.collection('heroSlides').doc(first.id).set(data(first));
    await firestore.collection('heroSlides').doc(second.id).set(data(second));

    await service.setAsFirstSlide(second.id);

    final firstData =
        (await firestore.collection('heroSlides').doc(first.id).get()).data()!;
    final secondData =
        (await firestore.collection('heroSlides').doc(second.id).get()).data()!;
    expect(firstData['isFirst'], isFalse);
    expect(secondData['isFirst'], isTrue);
  });

  test('reorderSlides persiste les index dans l ordre fourni', () async {
    final alpha = slide(id: 'alpha', order: 9);
    final beta = slide(id: 'beta', order: 4);
    final gamma = slide(id: 'gamma', order: 2);
    for (final value in <HeroSlide>[alpha, beta, gamma]) {
      await firestore.collection('heroSlides').doc(value.id).set(data(value));
    }

    await service.reorderSlides(<HeroSlide>[gamma, alpha, beta]);

    expect(
      (await firestore.collection('heroSlides').doc('gamma').get())['order'],
      0,
    );
    expect(
      (await firestore.collection('heroSlides').doc('alpha').get())['order'],
      1,
    );
    expect(
      (await firestore.collection('heroSlides').doc('beta').get())['order'],
      2,
    );
  });

  test('deleteSlide promeut la prochaine slide active', () async {
    final current = slide(id: 'current', order: 0, isFirst: true);
    final inactive = slide(id: 'inactive', order: 1, isActive: false);
    final replacement = slide(id: 'replacement', order: 2);
    for (final value in <HeroSlide>[current, inactive, replacement]) {
      await firestore.collection('heroSlides').doc(value.id).set(data(value));
    }

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
    expect(
      (await firestore.collection('heroSlides').doc(replacement.id).get())[
          'isFirst'],
      isTrue,
    );
  });

  test('updateSlide désactive une première slide et promeut la suivante',
      () async {
    final current = slide(id: 'current', order: 0, isFirst: true);
    final replacement = slide(id: 'replacement', order: 1);
    await firestore.collection('heroSlides').doc(current.id).set(data(current));
    await firestore
        .collection('heroSlides')
        .doc(replacement.id)
        .set(data(replacement));

    await service.updateSlide(
      current,
      title: '  Nouveau titre  ',
      isActive: false,
      scope: 'regional',
      targetRegions: const <String>['GP'],
    );

    final currentData =
        (await firestore.collection('heroSlides').doc(current.id).get()).data()!;
    final replacementData = (await firestore
            .collection('heroSlides')
            .doc(replacement.id)
            .get())
        .data()!;
    expect(currentData['title'], 'Nouveau titre');
    expect(currentData['isActive'], isFalse);
    expect(currentData['isFirst'], isFalse);
    expect(currentData['scope'], 'regional');
    expect(currentData['targetRegions'], <String>['GP']);
    expect(replacementData['isFirst'], isTrue);
  });
}
