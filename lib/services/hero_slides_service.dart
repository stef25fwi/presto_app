import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hero_slide.dart';

class HeroSlidesService {
  HeroSlidesService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? _defaultStorage(),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  // firebase_options.dart always configures a storage bucket on the default
  // app in production, but test suites that share a Firebase app across
  // files can leave the default app without one. Fall back to the project's
  // real bucket in that case instead of letting FirebaseStorage.instance
  // throw [firebase_storage/no-bucket].
  static FirebaseStorage _defaultStorage() {
    try {
      return FirebaseStorage.instance;
    } on FirebaseException catch (error) {
      if (error.code != 'no-bucket') {
        rethrow;
      }
      return FirebaseStorage.instanceFor(
        bucket: 'presto-app-74abe.firebasestorage.app',
      );
    }
  }

  CollectionReference<Map<String, dynamic>> get _slidesCollection =>
      _firestore.collection('heroSlides');

  User _requireSignedInUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseException(
        plugin: 'firebase_auth',
        code: 'unauthenticated',
        message: 'Utilisateur non connecté pour gérer les slides Hero.',
      );
    }
    return user;
  }

  static const _kSlidesCacheKey = 'hero_slides_cache_v1';

  /// Renvoie les slides sauvegardées localement (SharedPreferences).
  /// Retourne une liste vide si aucun cache n'existe encore.
  Future<List<HeroSlide>> loadCachedSlides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kSlidesCacheKey);
      if (jsonStr == null) return const [];
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) {
            final map = e as Map<String, dynamic>;
            return HeroSlide.fromMap(map['id']?.toString() ?? '', map);
          })
          .where((s) => s.mediaUrl.isNotEmpty && s.isActive)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persistSlidesCache(List<HeroSlide> slides) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(slides.map((s) => s.toJson()).toList());
      await prefs.setString(_kSlidesCacheKey, json);
    } catch (_) {
      // cache facultatif — aucune action requise en cas d'erreur
    }
  }

  Stream<List<HeroSlide>> watchActiveSlides() {
    return _slidesCollection.where('isActive', isEqualTo: true).snapshots().map(
      (snapshot) {
        final slides = _mapSnapshot(snapshot);
        _persistSlidesCache(slides); // fire-and-forget, non bloquant
        return slides;
      },
    );
  }

  /// Renvoie les slides actifs filtrés par région.
  /// Les slides globaux sont toujours inclus.
  /// Les slides régionaux sont inclus si [normalizedRegion] correspond à targetRegions.
  /// Si [normalizedRegion] est null, seuls les slides globaux sont renvoyés.
  Stream<List<HeroSlide>> watchSlidesForRegion(String? normalizedRegion) {
    return watchActiveSlides().map((slides) {
      return slides.where((slide) {
        if (slide.isGlobal) return true;
        if (slide.isRegional) {
          if (normalizedRegion == null || normalizedRegion.isEmpty) {
            return false;
          }
          if (slide.targetRegions.isEmpty) return false;
          return slide.targetRegions.contains(normalizedRegion);
        }
        return true; // fallback pour les anciens slides sans scope
      }).toList();
    });
  }

  /// Filtre une liste de slides en cache selon la région.
  List<HeroSlide> filterSlidesForRegion(
    List<HeroSlide> slides,
    String? normalizedRegion,
  ) {
    return slides.where((slide) {
      if (slide.isGlobal) return true;
      if (slide.isRegional) {
        if (normalizedRegion == null || normalizedRegion.isEmpty) return false;
        if (slide.targetRegions.isEmpty) return false;
        return slide.targetRegions.contains(normalizedRegion);
      }
      return true;
    }).toList();
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
    String scope = 'global',
    List<String> targetRegions = const [],
    double focalX = 0.5,
    double focalY = 0.5,
    void Function(double progress)? onUploadProgress,
  }) async {
    final user = _requireSignedInUser();
    final normalizedMediaType = _normalizeMediaType(mediaType);
    final slides = await _fetchAllSlides();
    final nextOrder = order ?? _nextOrder(slides);
    final shouldBeFirst = isFirst || slides.isEmpty;
    final uploadResult = await uploadHeroMedia(
      fileBytes: fileBytes,
      fileName: fileName,
      mediaType: normalizedMediaType,
      contentType: contentType,
      onProgress: onUploadProgress,
    );
    _verifyHeroMediaUpload(uploadResult);
    final docRef = _slidesCollection.doc();
    final batch = _firestore.batch();
    final normalizedTitle = _normalizeTitle(title, fileName: fileName);

    if (shouldBeFirst) {
      for (final slide in slides.where((slide) => slide.isFirst)) {
        batch.update(_slidesCollection.doc(slide.id), <String, dynamic>{
          'isFirst': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    final normalizedScope = scope == 'regional' ? 'regional' : 'global';
    batch.set(docRef, <String, dynamic>{
      'id': docRef.id,
      'title': normalizedTitle,
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
      'createdBy': user.uid,
      'scope': normalizedScope,
      'targetRegions': targetRegions,
      'focalX': focalX.clamp(0.0, 1.0).toDouble(),
      'focalY': focalY.clamp(0.0, 1.0).toDouble(),
    });

    try {
      await batch.commit();
    } catch (error) {
      await _cleanupUploadedHeroMedia(uploadResult.storagePath);
      rethrow;
    }
  }

  Future<void> updateSlide(
    HeroSlide slide, {
    String? title,
    int? durationSeconds,
    int? order,
    bool? isActive,
    bool? isFirst,
    String? scope,
    List<String>? targetRegions,
    double? focalX,
    double? focalY,
    Uint8List? replacementFileBytes,
    String? replacementFileName,
    String? replacementMediaType,
    String? replacementContentType,
    void Function(double progress)? onUploadProgress,
  }) async {
    _requireSignedInUser();
    final slides = await _fetchAllSlides();
    final docRef = _slidesCollection.doc(slide.id);
    var nextMediaUrl = slide.mediaUrl;
    var nextStoragePath = slide.storagePath;
    var nextMediaType = slide.mediaType;
    String? previousStoragePath;
    String? uploadedReplacementStoragePath;

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
      _verifyHeroMediaUpload(uploadResult);
      previousStoragePath = slide.storagePath;
      nextMediaUrl = uploadResult.mediaUrl;
      nextStoragePath = uploadResult.storagePath;
      uploadedReplacementStoragePath = uploadResult.storagePath;
      nextMediaType = _normalizeMediaType(
        replacementMediaType ?? slide.mediaType,
      );
    }

    final nextIsActive = isActive ?? slide.isActive;
    final requestedFirst = isFirst ?? slide.isFirst;
    final shouldBeFirst = requestedFirst && nextIsActive;
    final batch = _firestore.batch();

    if (shouldBeFirst) {
      for (final other in slides.where(
        (entry) => entry.id != slide.id && entry.isFirst,
      )) {
        batch.update(_slidesCollection.doc(other.id), <String, dynamic>{
          'isFirst': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    final nextOrder = order ?? slide.order;
    final normalizedTitle = _normalizeTitle(
      title ?? slide.title,
      fileName: replacementFileName ?? slide.title,
    );
    final nextScope =
        (scope ?? slide.scope) == 'regional' ? 'regional' : 'global';
    final nextTargetRegions = targetRegions ?? slide.targetRegions;
    batch.update(docRef, <String, dynamic>{
      'title': normalizedTitle,
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
      'scope': nextScope,
      'targetRegions': nextTargetRegions,
      'focalX': (focalX ?? slide.focalX).clamp(0.0, 1.0).toDouble(),
      'focalY': (focalY ?? slide.focalY).clamp(0.0, 1.0).toDouble(),
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

    try {
      await batch.commit();
    } catch (error) {
      if (uploadedReplacementStoragePath != null &&
          uploadedReplacementStoragePath != slide.storagePath) {
        await _cleanupUploadedHeroMedia(uploadedReplacementStoragePath);
      }
      rethrow;
    }

    if (previousStoragePath != null &&
        previousStoragePath.isNotEmpty &&
        previousStoragePath != nextStoragePath) {
      await _cleanupUploadedHeroMedia(previousStoragePath);
    }
  }

  Future<void> deleteSlide(HeroSlide slide) async {
    _requireSignedInUser();
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
      await _cleanupUploadedHeroMedia(slide.storagePath);
    }
  }

  Future<void> setAsFirstSlide(String slideId) async {
    _requireSignedInUser();
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
    _requireSignedInUser();
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
    if (fileBytes.isEmpty) {
      throw StateError('Le fichier sélectionné est vide.');
    }

    final normalizedFileName = fileName.trim();
    if (normalizedFileName.isEmpty) {
      throw StateError('Nom de fichier invalide pour l\'upload Hero.');
    }

    final normalizedMediaType = _normalizeMediaType(mediaType);
    final extension = _fileExtension(normalizedFileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = _safeFileName(
      normalizedFileName,
      fallback: 'slide.$extension',
    );
    final storagePath = 'hero_slides/${timestamp}_$safeName';
    final ref = _storage.ref().child(storagePath);

    final uploadTask = ref.putData(
      fileBytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: <String, String>{'mediaType': normalizedMediaType},
      ),
    );

    StreamSubscription<TaskSnapshot>? progressSubscription;
    try {
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
      onProgress?.call(1);
    } finally {
      await progressSubscription?.cancel();
    }

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
    final slides =
        snapshot.docs.map(HeroSlide.fromFirestore).toList(growable: false);
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
    return value.clamp(3, 60).toInt();
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

  String _normalizeTitle(String value, {required String fileName}) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed.length > 80 ? trimmed.substring(0, 80) : trimmed;
    }

    final withoutExtension = fileName.trim().replaceFirst(
          RegExp(r'\.[^.]+$'),
          '',
        );
    final fallback = withoutExtension.isEmpty ? 'Slide Hero' : withoutExtension;
    return fallback.length > 80 ? fallback.substring(0, 80) : fallback;
  }

  void _verifyHeroMediaUpload(HeroMediaUploadResult uploadResult) {
    if (uploadResult.mediaUrl.trim().isEmpty ||
        !uploadResult.storagePath.startsWith('hero_slides/')) {
      throw StateError('Hero media upload did not return a Firebase URL/path.');
    }
  }

  Future<void> _cleanupUploadedHeroMedia(String? storagePath) async {
    final normalizedPath = storagePath?.trim() ?? '';
    if (normalizedPath.isEmpty) {
      return;
    }

    try {
      await deleteHeroMedia(normalizedPath);
    } catch (_) {
      // Best effort cleanup: preserve the original Firestore failure.
    }
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
