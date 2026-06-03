import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/hero_slide.dart';

class HeroSlidesService {
  HeroSlidesService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _slidesCollection =>
      _firestore.collection('heroSlides');

  Stream<List<HeroSlide>> watchActiveSlides() {
    return _slidesCollection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(_mapSnapshot);
  }

  Stream<List<HeroSlide>> watchAllSlidesForAdmin() {
    return _slidesCollection.snapshots().map(_mapSnapshot);
  }

  Future<void> addSlide({
    required Uint8List fileBytes,
    required String fileName,
    required String mediaType,
    required String contentType,
    String title = '',
    int? durationSeconds,
    int? order,
    bool isActive = true,
    bool isFirst = false,
    void Function(double progress)? onUploadProgress,
  }) async {
    final normalizedMediaType = _normalizeMediaType(mediaType);
    final slides = await _fetchAllSlides();
    final now = DateTime.now();
    final nextOrder = order ?? _nextOrder(slides);
    final shouldBeFirst = isFirst || slides.isEmpty;
    final uploadResult = await uploadHeroMedia(
      fileBytes: fileBytes,
      fileName: fileName,
      mediaType: normalizedMediaType,
      contentType: contentType,
      onProgress: onUploadProgress,
    );
    final docRef = _slidesCollection.doc();
    final batch = _firestore.batch();

    if (shouldBeFirst) {
      for (final slide in slides.where((slide) => slide.isFirst)) {
        batch.update(_slidesCollection.doc(slide.id), <String, dynamic>{
          'isFirst': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    batch.set(docRef, <String, dynamic>{
      'id': docRef.id,
      'title': title.trim(),
      'mediaUrl': uploadResult.mediaUrl,
      'storagePath': uploadResult.storagePath,
      'mediaType': normalizedMediaType,
      'durationSeconds': _normalizeDuration(
        durationSeconds,
        mediaType: normalizedMediaType,
      ),
      'order': nextOrder,
      'isActive': isActive,
      'isFirst': shouldBeFirst,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': _auth.currentUser?.uid,
      'updatedBy': _auth.currentUser?.uid,
    });

    await batch.commit();
  }

  Future<void> updateSlide(
    HeroSlide slide, {
    String? title,
    int? durationSeconds,
    int? order,
    bool? isActive,
    bool? isFirst,
    Uint8List? replacementFileBytes,
    String? replacementFileName,
    String? replacementMediaType,
    String? replacementContentType,
    void Function(double progress)? onUploadProgress,
  }) async {
    final slides = await _fetchAllSlides();
    final docRef = _slidesCollection.doc(slide.id);
    var nextMediaUrl = slide.mediaUrl;
    var nextStoragePath = slide.storagePath;
    var nextMediaType = slide.mediaType;
    String? previousStoragePath;

    if (replacementFileBytes != null &&
        replacementFileName != null &&
        replacementContentType != null) {
      final uploadResult = await uploadHeroMedia(
        fileBytes: replacementFileBytes,
        fileName: replacementFileName,
        mediaType: _normalizeMediaType(replacementMediaType ?? slide.mediaType),
        contentType: replacementContentType,
        onProgress: onUploadProgress,
      );
      previousStoragePath = slide.storagePath;
      nextMediaUrl = uploadResult.mediaUrl;
      nextStoragePath = uploadResult.storagePath;
      nextMediaType =
          _normalizeMediaType(replacementMediaType ?? slide.mediaType);
    }

    final nextIsActive = isActive ?? slide.isActive;
    final requestedFirst = isFirst ?? slide.isFirst;
    final shouldBeFirst = requestedFirst && nextIsActive;
    final batch = _firestore.batch();

    if (shouldBeFirst) {
      for (final other in slides.where((entry) => entry.id != slide.id && entry.isFirst)) {
        batch.update(_slidesCollection.doc(other.id), <String, dynamic>{
          'isFirst': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    final nextOrder = order ?? slide.order;
    batch.update(docRef, <String, dynamic>{
      'title': (title ?? slide.title).trim(),
      'mediaUrl': nextMediaUrl,
      'storagePath': nextStoragePath,
      'mediaType': nextMediaType,
      'durationSeconds': _normalizeDuration(
        durationSeconds ?? slide.durationSeconds,
        mediaType: nextMediaType,
      ),
      'order': nextOrder,
      'isActive': nextIsActive,
      'isFirst': shouldBeFirst,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    });

    if (slide.isFirst && !shouldBeFirst) {
      final replacement = _findReplacementFirst(
        slides: slides.where((entry) => entry.id != slide.id).toList(),
      );
      if (replacement != null) {
        batch.update(_slidesCollection.doc(replacement.id), <String, dynamic>{
          'isFirst': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();

    if (previousStoragePath != null &&
        previousStoragePath.isNotEmpty &&
        previousStoragePath != nextStoragePath) {
      await deleteHeroMedia(previousStoragePath);
    }
  }

  Future<void> deleteSlide(HeroSlide slide) async {
    final slides = await _fetchAllSlides();
    final batch = _firestore.batch();
    batch.delete(_slidesCollection.doc(slide.id));

    if (slide.isFirst) {
      final replacement = _findReplacementFirst(
        slides: slides.where((entry) => entry.id != slide.id).toList(),
      );
      if (replacement != null) {
        batch.update(_slidesCollection.doc(replacement.id), <String, dynamic>{
          'isFirst': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();

    if (slide.storagePath.trim().isNotEmpty) {
      await deleteHeroMedia(slide.storagePath);
    }
  }

  Future<void> setAsFirstSlide(String slideId) async {
    final slides = await _fetchAllSlides();
    final batch = _firestore.batch();

    for (final slide in slides) {
      batch.update(_slidesCollection.doc(slide.id), <String, dynamic>{
        'isFirst': slide.id == slideId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> reorderSlides(List<HeroSlide> slides) async {
    final batch = _firestore.batch();

    for (var index = 0; index < slides.length; index += 1) {
      batch.update(_slidesCollection.doc(slides[index].id), <String, dynamic>{
        'order': index,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<HeroMediaUploadResult> uploadHeroMedia({
    required Uint8List fileBytes,
    required String fileName,
    required String mediaType,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    final normalizedMediaType = _normalizeMediaType(mediaType);
    final extension = _fileExtension(fileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = _safeFileName(fileName, fallback: 'slide.$extension');
    final storagePath = 'hero_slides/${timestamp}_$safeName';
    final ref = _storage.ref().child(storagePath);

    final uploadTask = ref.putData(
      fileBytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: <String, String>{
          'mediaType': normalizedMediaType,
        },
      ),
    );

    StreamSubscription<TaskSnapshot>? progressSubscription;
    if (onProgress != null) {
      progressSubscription = uploadTask.snapshotEvents.listen((snapshot) {
        final totalBytes = snapshot.totalBytes;
        if (totalBytes <= 0) {
          return;
        }
        onProgress(snapshot.bytesTransferred / totalBytes);
      });
    }

    await uploadTask;
    await progressSubscription?.cancel();
    onProgress?.call(1);

    final mediaUrl = await ref.getDownloadURL();
    return HeroMediaUploadResult(
      mediaUrl: mediaUrl.trim(),
      storagePath: storagePath,
      mediaType: normalizedMediaType,
    );
  }

  Future<void> deleteHeroMedia(String storagePath) async {
    final normalizedPath = storagePath.trim();
    if (normalizedPath.isEmpty) {
      return;
    }

    try {
      await _storage.ref().child(normalizedPath).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  Future<List<HeroSlide>> _fetchAllSlides() async {
    final snapshot = await _slidesCollection.get();
    return _mapSnapshot(snapshot);
  }

  List<HeroSlide> _mapSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final slides = snapshot.docs
        .map(HeroSlide.fromFirestore)
        .toList(growable: false);
    slides.sort(HeroSlide.compareDisplayOrder);
    return slides;
  }

  HeroSlide? _findReplacementFirst({required List<HeroSlide> slides}) {
    final activeSlides = slides.where((slide) => slide.isActive).toList();
    if (activeSlides.isEmpty) {
      return null;
    }
    activeSlides.sort(HeroSlide.compareDisplayOrder);
    return activeSlides.first;
  }

  int _nextOrder(List<HeroSlide> slides) {
    if (slides.isEmpty) {
      return 0;
    }
    final maxOrder = slides
        .map((slide) => slide.order)
        .reduce((left, right) => left > right ? left : right);
    return maxOrder + 1;
  }

  int _normalizeDuration(int? value, {required String mediaType}) {
    final fallback = mediaType == 'video' ? 10 : 5;
    if (value == null) {
      return fallback;
    }
    return value < 1 ? fallback : value;
  }

  String _normalizeMediaType(String value) {
    return value.trim().toLowerCase() == 'video' ? 'video' : 'image';
  }

  String _safeFileName(String name, {required String fallback}) {
    final trimmed = name.trim();
    final source = trimmed.isEmpty ? fallback : trimmed;
    final sanitized = source
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return sanitized.isEmpty ? fallback : sanitized;
  }

  String _fileExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == fileName.length - 1) {
      return 'bin';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }
}

class HeroMediaUploadResult {
  final String mediaUrl;
  final String storagePath;
  final String mediaType;

  const HeroMediaUploadResult({
    required this.mediaUrl,
    required this.storagePath,
    required this.mediaType,
  });
}