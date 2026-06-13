import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PaymentInfoAudioService {
  PaymentInfoAudioService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const String storagePath = 'audio/payment_info_popup_fr.mp3';
  static const String configCollection = 'app_config';
  static const String configDoc = 'payment_info_audio';

  Stream<String?> watchAudioUrl() {
    return _firestore
        .collection(configCollection)
        .doc(configDoc)
        .snapshots()
        .map((doc) => doc.data()?['audioUrl'] as String?);
  }

  Future<String?> getStorageAudioUrl() async {
    try {
      return await _storage.ref(storagePath).getDownloadURL();
    } on FirebaseException {
      return null;
    }
  }

  Future<void> saveAudioUrl(String audioUrl, {String? fileName}) async {
    await _firestore.collection(configCollection).doc(configDoc).set({
      'audioUrl': audioUrl,
      'storagePath': storagePath,
      'updatedAt': FieldValue.serverTimestamp(),
      if (fileName != null) 'fileName': fileName,
    }, SetOptions(merge: true));
  }

  Future<void> uploadAudio(Uint8List bytes, String fileName) async {
    final ref = _storage.ref(storagePath);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'audio/mpeg',
        customMetadata: {
          'usage': 'payment_info_popup',
          'fileName': fileName,
        },
      ),
    );
    final url = await ref.getDownloadURL();
    await saveAudioUrl(url, fileName: fileName);
  }
}
