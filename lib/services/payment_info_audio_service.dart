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
  Future<String> getStorageAudioUrl() {
    return _storage.ref(storagePath).getDownloadURL();
  }
  Future<void> saveAudioUrl(String audioUrl) async {
    await _firestore.collection(configCollection).doc(configDoc).set({
      'audioUrl': audioUrl,
      'storagePath': storagePath,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
