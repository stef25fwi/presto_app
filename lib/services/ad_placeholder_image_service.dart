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
    this.title,
    this.description,
    this.linkUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String imageUrl;
  final String storagePath;
  final bool isVisible;
  final String target;
  final int sortOrder;
  final String? title;
  final String? description;
  final String? linkUrl;
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
      title: (data['title'] ?? '').toString().isEmpty ? null : (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString().isEmpty ? null : (data['description'] ?? '').toString(),
      linkUrl: (data['linkUrl'] ?? '').toString().isEmpty ? null : (data['linkUrl'] ?? '').toString(),
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
    void Function(double progress)? onUploadProgress,
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

    final uploadTask = ref.putData(
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

    final subscription = uploadTask.snapshotEvents.listen((snapshot) {
      final total = snapshot.totalBytes;
      if (total > 0) {
        onUploadProgress?.call(snapshot.bytesTransferred / total);
      }
    });

    try {
      await uploadTask;
      onUploadProgress?.call(1);
    } finally {
      await subscription.cancel();
    }

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
      'title': '',
      'description': '',
      'linkUrl': '',
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

  static Future<void> updateSlideProperties({
    required String id,
    String? title,
    String? description,
    String? linkUrl,
  }) async {
    await _collection.doc(id).update({
      if (title != null) 'title': title.isEmpty ? FieldValue.delete() : title,
      if (description != null) 'description': description.isEmpty ? FieldValue.delete() : description,
      if (linkUrl != null) 'linkUrl': linkUrl.isEmpty ? FieldValue.delete() : linkUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> replaceSlideImage({
    required String id,
    required AdPlaceholderImage currentImage,
    required XFile newFile,
    String target = 'consult_offers',
    void Function(double progress)? onUploadProgress,
  }) async {
    // Télécharger la nouvelle image
    final Uint8List bytes = await newFile.readAsBytes();
    final now = DateTime.now().millisecondsSinceEpoch;
    final safeBaseName = newFile.name
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final extension = _extensionFromName(newFile.name);
    final contentType = _guessContentType(newFile.name);
    final storagePath = 'ad_placeholders/$target/$now-$safeBaseName.$extension';
    final ref = _storage.ref(storagePath);

    final uploadTask = ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        cacheControl: 'public,max-age=604800',
        customMetadata: {
          'originalName': newFile.name,
          'recommendedFormat': 'webp',
          'recommendedWidthPx': '$recommendedWidthPx',
          'recommendedMinWidthPx': '$recommendedMinWidthPx',
          'recommendedHeight16x9Px': '$recommendedHeight16x9Px',
          'recommendedMaxWeightKb': '$recommendedMaxWeightKb',
          'clientWebpConversion': 'disabled-build-safe',
        },
      ),
    );

    final subscription = uploadTask.snapshotEvents.listen((snapshot) {
      final total = snapshot.totalBytes;
      if (total > 0) {
        onUploadProgress?.call(snapshot.bytesTransferred / total);
      }
    });

    try {
      await uploadTask;
      onUploadProgress?.call(1);
    } finally {
      await subscription.cancel();
    }

    final url = await ref.getDownloadURL();

    // Supprimer l'ancienne image du storage
    if (currentImage.storagePath.isNotEmpty) {
      try {
        await _storage.ref(currentImage.storagePath).delete();
      } catch (_) {
        // Continuer même si suppression échoue
      }
    }

    // Mettre à jour Firestore
    await _collection.doc(id).update({
      'imageUrl': url,
      'storagePath': storagePath,
      'format': extension,
      'originalName': newFile.name,
      'originalBytes': bytes.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
