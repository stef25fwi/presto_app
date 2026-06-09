import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/professional_profile.dart';
import '../models/siret_verification.dart';
import '../models/user_review.dart';

class ProfessionalProfileService {
  ProfessionalProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection('professional_profiles');

  CollectionReference<Map<String, dynamic>> get _siretVerifications =>
      _firestore.collection('siret_verifications');

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _firestore.collection('reviews');

  CollectionReference<Map<String, dynamic>> get _reviewSummaries =>
      _firestore.collection('review_summaries');

  Stream<ProfessionalProfile?> watchProfile(String userId) {
    return _profiles.doc(userId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return ProfessionalProfile.fromMap(snapshot.id, data);
    });
  }

  Future<ProfessionalProfile?> getProfile(String userId) async {
    final snapshot = await _profiles.doc(userId).get();
    final data = snapshot.data();
    if (data == null) return null;
    return ProfessionalProfile.fromMap(snapshot.id, data);
  }

  Future<void> saveProfile(ProfessionalProfile profile) async {
    await _profiles.doc(profile.userId).set(
      {
        ...profile.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> submitSiretForVerification({
    required String userId,
    required String siret,
    required String region,
    required String department,
    required String city,
  }) async {
    final cleanedSiret = siret.replaceAll(RegExp(r'\D'), '');

    if (cleanedSiret.length != 14) {
      throw ArgumentError('Le SIRET doit contenir 14 chiffres.');
    }

    final doc = _siretVerifications.doc();

    await doc.set({
      'userId': userId,
      'siret': cleanedSiret,
      'region': region,
      'department': department,
      'city': city,
      'status': 'en_attente',
      'source': 'user_submission',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _profiles.doc(userId).set(
      {
        'userId': userId,
        'siret': cleanedSiret,
        'siretStatus': 'en_attente',
        'region': region,
        'department': department,
        'city': city,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Stream<List<SiretVerification>> watchPendingSiretVerifications() {
    return _siretVerifications
        .where('status', isEqualTo: 'en_attente')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SiretVerification.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> updateSiretVerificationStatus({
    required String verificationId,
    required String userId,
    required String status,
    String? businessName,
    String? activityLabel,
    String? adminNote,
  }) async {
    final allowedStatuses = {
      'en_attente',
      'valide',
      'invalide',
      'a_revoir',
    };

    if (!allowedStatuses.contains(status)) {
      throw ArgumentError('Statut SIRET invalide : $status');
    }

    await _firestore.runTransaction((transaction) async {
      final verificationRef = _siretVerifications.doc(verificationId);
      final profileRef = _profiles.doc(userId);

      transaction.set(
        verificationRef,
        {
          'status': status,
          'businessName': businessName,
          'activityLabel': activityLabel,
          'adminNote': adminNote,
          'checkedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      transaction.set(
        profileRef,
        {
          'siretStatus': status,
          'businessName': businessName,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Stream<List<UserReview>> watchUserReviews(String reviewedUserId) {
    return _reviews
        .where('reviewedUserId', isEqualTo: reviewedUserId)
        .where('status', isEqualTo: 'published')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserReview.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> createReview(UserReview review) async {
    if (review.rating < 1 || review.rating > 5) {
      throw ArgumentError('La note doit être comprise entre 1 et 5.');
    }

    final docRef = review.id.trim().isEmpty
        ? _reviews.doc()
        : _reviews.doc(review.id.trim());

    await docRef.set({
      ...review.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await recomputeReviewSummary(review.reviewedUserId);
  }

  Future<void> recomputeReviewSummary(String userId) async {
    final snapshot = await _reviews
        .where('reviewedUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'published')
        .get();

    final reviews = snapshot.docs
        .map((doc) => UserReview.fromMap(doc.id, doc.data()))
        .toList();

    if (reviews.isEmpty) {
      await _reviewSummaries.doc(userId).set(
        {
          'userId': userId,
          'averageRating': 0,
          'reviewCount': 0,
          'providerReviewCount': 0,
          'clientReviewCount': 0,
          'trustScore': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await _profiles.doc(userId).set(
        {
          'averageRating': 0,
          'reviewCount': 0,
          'trustScore': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return;
    }

    final totalRating = reviews.fold<int>(
      0,
      (total, review) => total + review.rating,
    );

    final averageRating = totalRating / reviews.length;

    final providerReviewCount =
        reviews.where((review) => review.isProviderReview).length;

    final clientReviewCount =
        reviews.where((review) => review.isClientReview).length;

    final trustScore = _calculateTrustScore(
      averageRating: averageRating,
      reviewCount: reviews.length,
    );

    await _reviewSummaries.doc(userId).set(
      {
        'userId': userId,
        'averageRating': averageRating,
        'reviewCount': reviews.length,
        'providerReviewCount': providerReviewCount,
        'clientReviewCount': clientReviewCount,
        'trustScore': trustScore,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await _profiles.doc(userId).set(
      {
        'averageRating': averageRating,
        'reviewCount': reviews.length,
        'trustScore': trustScore,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  int _calculateTrustScore({
    required double averageRating,
    required int reviewCount,
  }) {
    final ratingScore = (averageRating / 5 * 70).round();
    final volumeScore =
        reviewCount >= 20 ? 30 : (reviewCount / 20 * 30).round();
    return (ratingScore + volumeScore).clamp(0, 100);
  }
}
