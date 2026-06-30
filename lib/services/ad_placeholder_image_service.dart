import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AdPlaceholderImage {
  const AdPlaceholderImage({
    required this.id,
    required this.imageUrl,
    required this.storagePath,
    required this.isVisible,
    required this.target,
    required this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String imageUrl;
  final String storagePath;
  final bool isVisible;
  final String target;
  final int sortOrder;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  static AdPlaceholderImage fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return AdPlaceholderImage(
      id: doc.id,
      imageUrl: (data['imageUrl'] ?? '').toString(),
      storagePath: (data['storagePath'] ?? '').toString(),
      isVisible: data['isVisible'] == true,
      target: (data['target'] ?? 'consult_offers').toString(),
      sortOrder: data['sortOrder'] is int ? data['sortOrder'] as int : 0,
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : null,
      updatedAt: data['updatedAt'] is Timestamp
          ? data['updatedAt'] as Timestamp
          : null,
    );
  }
}

class AdPlaceholderImageService {
  AdPlaceholderImageService._();

  static const int recommendedWidthPx = 1920;
  static const int recommendedMinWidthPx = 1600;
  static const int recommendedHeight16x9Px = 1080;
  static const int recommendedMaxWeightKb = 450;

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('ad_placeholder_images');

  static Stream<List<AdPlaceholderImage>> watchAll({
    String target = 'consult_offers',
  }) {
    return _collection
        .where('target', isEqualTo: target)
        .orderBy('sortOrder')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(AdPlaceholderImage.fromDoc).toList(),
        );
  }

  static Stream<List<AdPlaceholderImage>> watchVisible({
    String target = 'consult_offers',
  }) {
    return _collection
        .where('target', isEqualTo: target)
        .where('isVisible', isEqualTo: true)
        .orderBy('sortOrder')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(AdPlaceholderImage.fromDoc).toList(),
        );
  }

  static Future<void> uploadImage({
    required XFile file,
    String target = 'consult_offers',
  }) async {
    final Uint8List bytes = await file.readAsBytes();

    final now = DateTime.now().millisecondsSinceEpoch;
    final safeBaseName = file.name
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final extension = _extensionFromName(file.name);
    final contentType = _guessContentType(file.name);

    final storagePath = 'ad_placeholders/$target/$now-$safeBaseName.$extension';

    final ref = _storage.ref(storagePath);

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        cacheControl: 'public,max-age=604800',
        customMetadata: {
          'originalName': file.name,
          'recommendedFormat': 'webp',
          'recommendedWidthPx': '$recommendedWidthPx',
          'recommendedMinWidthPx': '$recommendedMinWidthPx',
          'recommendedHeight16x9Px': '$recommendedHeight16x9Px',
          'recommendedMaxWeightKb': '$recommendedMaxWeightKb',
          'clientWebpConversion': 'disabled-build-safe',
        },
      ),
    );

    final url = await ref.getDownloadURL();

    await _collection.add({
      'target': target,
      'imageUrl': url,
      'storagePath': storagePath,
      'isVisible': true,
      'sortOrder': now,
      'format': extension,
      'originalName': file.name,
      'originalBytes': bytes.length,
      'recommendedFormat': 'webp',
      'recommendedWidthPx': recommendedWidthPx,
      'recommendedMinWidthPx': recommendedMinWidthPx,
      'recommendedHeight16x9Px': recommendedHeight16x9Px,
      'recommendedMaxWeightKb': recommendedMaxWeightKb,
      'clientWebpConversion': 'disabled-build-safe',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setVisible({
    required String id,
    required bool isVisible,
  }) {
    return _collection.doc(id).update({
      'isVisible': isVisible,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> reorderImages(List<String> orderedIds) async {
    final batch = _firestore.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(_collection.doc(orderedIds[i]), {
        'sortOrder': i * 1000,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  static Future<void> deleteImage(AdPlaceholderImage image) async {
    if (image.storagePath.isNotEmpty) {
      try {
        await _storage.ref(image.storagePath).delete();
      } catch (_) {
        // Si le fichier Storage a déjà été supprimé,
        // on supprime quand même la fiche Firestore.
      }
    }

    await _collection.doc(image.id).delete();
  }

  static String _extensionFromName(String name) {
    final lower = name.toLowerCase();

    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';

    return 'jpg';
  }

  static String _guessContentType(String name) {
    final lower = name.toLowerCase();

    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    return 'image/jpeg';
  }
}
