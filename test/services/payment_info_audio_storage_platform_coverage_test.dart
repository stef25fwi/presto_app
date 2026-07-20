// The platform interface is used only to provide a deterministic in-memory
// Firebase Storage delegate for this integration boundary.
// ignore_for_file: depend_on_referenced_packages

import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_storage_platform_interface/firebase_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';

class _MemoryStoragePlatform extends FirebaseStoragePlatform {
  _MemoryStoragePlatform() : super(bucket: 'presto-audio-test.appspot.com');

  _MemoryReference? lastReference;

  @override
  FirebaseStoragePlatform delegateFor({
    required FirebaseApp app,
    required String bucket,
  }) => this;

  @override
  ReferencePlatform ref(String path) {
    final reference = _MemoryReference(this, path);
    lastReference = reference;
    return reference;
  }

  @override
  int get maxDownloadRetryTime => 0;

  @override
  int get maxOperationRetryTime => 0;

  @override
  int get maxUploadRetryTime => 0;
}

class _MemoryReference extends ReferencePlatform {
  _MemoryReference(super.storage, super.path);

  Uint8List? uploadedBytes;
  SettableMetadata? uploadedMetadata;

  @override
  TaskPlatform putData(Uint8List data, [SettableMetadata? metadata]) {
    uploadedBytes = Uint8List.fromList(data);
    uploadedMetadata = metadata;
    return _CompletedUploadTask(this, data.length);
  }

  @override
  Future<String> getDownloadURL() async {
    return 'https://storage.test/$fullPath';
  }
}

class _CompletedUploadSnapshot extends TaskSnapshotPlatform {
  _CompletedUploadSnapshot(this.reference, int byteCount)
      : super(
          TaskState.success,
          <String, dynamic>{
            'bytesTransferred': byteCount,
            'totalBytes': byteCount,
            'metadata': null,
          },
        );

  final ReferencePlatform reference;

  @override
  ReferencePlatform get ref => reference;
}

class _CompletedUploadTask extends TaskPlatform {
  _CompletedUploadTask(ReferencePlatform reference, int byteCount)
      : _snapshot = _CompletedUploadSnapshot(reference, byteCount);

  final TaskSnapshotPlatform _snapshot;

  @override
  TaskSnapshotPlatform get snapshot => _snapshot;

  @override
  Stream<TaskSnapshotPlatform> get snapshotEvents =>
      Stream<TaskSnapshotPlatform>.value(_snapshot);

  @override
  Future<TaskSnapshotPlatform> get onComplete async => _snapshot;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseStoragePlatform originalStoragePlatform;
  late _MemoryStoragePlatform storagePlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: '1:123456789:web:payment-audio-storage',
          messagingSenderId: '123456789',
          projectId: 'presto-audio-test',
          storageBucket: 'presto-audio-test.appspot.com',
        ),
      );
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    originalStoragePlatform = FirebaseStoragePlatform.instance;
  });

  setUp(() {
    storagePlatform = _MemoryStoragePlatform();
    FirebaseStoragePlatform.instance = storagePlatform;
  });

  tearDown(() {
    FirebaseStoragePlatform.instance = originalStoragePlatform;
    PaymentInfoAudioService.setFirestoreForTesting(null);
    PaymentInfoAudioService.setCallableForTesting(null);
    PaymentInfoAudioService.setTextSaverForTesting(null);
  });

  test('utilise Storage par défaut puis publie les métadonnées Firestore',
      () async {
    final firestore = FakeFirebaseFirestore();
    PaymentInfoAudioService.setFirestoreForTesting(firestore);

    final service = PaymentInfoAudioService(
      callable: (_, __) async {},
    );
    final bytes = Uint8List.fromList(<int>[4, 8, 15, 16, 23, 42]);

    await service.uploadAudio(bytes, 'payment-rules.mp3');

    final reference = storagePlatform.lastReference;
    expect(reference, isNotNull);
    expect(reference!.fullPath, startsWith('payment_info_audio/'));
    expect(reference.fullPath, endsWith('_payment-rules.mp3'));
    expect(reference.uploadedBytes, orderedEquals(bytes));
    expect(reference.uploadedMetadata?.contentType, 'audio/mpeg');

    final snapshot = await firestore
        .collection('public_config')
        .doc('payment_info_audio')
        .get();
    final data = snapshot.data();
    expect(data, isNotNull);
    expect(data!['enabled'], isTrue);
    expect(data['audioUrl'], 'https://storage.test/${reference.fullPath}');
    expect(data['storagePath'], reference.fullPath);
    expect(data['contentType'], 'audio/mpeg');
    expect(data['provider'], 'manual_upload');
  });
}
