import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/user_profile_bootstrap_service.dart';

class AuthUserProfileService {
  AuthUserProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> ensureEmailUserProfile({
    required User user,
    required String displayName,
    required bool isBusinessAccount,
  }) async {
    await UserProfileBootstrapService.ensureUserDocument(
      user: user,
      authMethod: 'email',
      isNewUserHint: true,
      forceRefresh: true,
    );

    final now = FieldValue.serverTimestamp();
    final email = user.email?.trim().toLowerCase() ?? '';
    final normalizedDisplayName = displayName.trim();

    await _firestore.collection('users').doc(user.uid).set(
      <String, dynamic>{
        'uid': user.uid,
        if (email.isNotEmpty) 'email': email,
        'displayName': normalizedDisplayName,
        'pseudo': normalizedDisplayName,
        'provider': 'email',
        'lastAuthMethod': 'email',
        'accountType': isBusinessAccount ? 'Entreprise' : 'Particulier',
        'profileKind': isBusinessAccount ? 'business' : 'individual',
        'profileCompleted': false,
        'emailVerified': user.emailVerified,
        'updatedAt': now,
        'lastLoginAt': now,
        if (isBusinessAccount)
          'businessProfile': <String, dynamic>{
            'status': 'draft',
            'verificationRequired': true,
            'publicProfileReady': false,
            'updatedAt': now,
          },
      },
      SetOptions(merge: true),
    );

    if (isBusinessAccount) {
      await ensureBusinessProfileDraft(
        user: user,
        displayName: normalizedDisplayName,
      );
    }
  }

  Future<void> ensureBusinessProfileDraft({
    required User user,
    required String displayName,
  }) async {
    await UserProfileBootstrapService.prepareProfileFirestoreAccess(
      user: user,
      forceRefreshToken: true,
      forceRefreshAppCheckToken: true,
    );

    final proRef = _firestore.collection('pros').doc(user.uid);
    final existing = await proRef.get();
    final now = FieldValue.serverTimestamp();
    final email = user.email?.trim().toLowerCase() ?? '';
    final normalizedDisplayName = displayName.trim();

    final baseProfile = <String, dynamic>{
      'uid': user.uid,
      'profileType': 'enterprise',
      'companyName': '',
      'legalName': '',
      'tradeName': '',
      'siret': '',
      'activity': '',
      'description': '',
      'contactName': normalizedDisplayName,
      if (email.isNotEmpty) 'contactEmail': email,
      'contactPhone': '',
      'website': '',
      'address': '',
      'city': '',
      'postalCode': '',
      'serviceAreas': <String>[],
      'categories': <String>[],
      'documents': <String, dynamic>{
        'identity': <String, dynamic>{'status': 'missing'},
        'company': <String, dynamic>{'status': 'missing'},
      },
      'publicProfile': <String, dynamic>{
        'displayName': normalizedDisplayName,
        'headline': '',
        'visible': false,
      },
      'ratingSummary': <String, dynamic>{
        'average': 0,
        'count': 0,
      },
      'requestStats': <String, dynamic>{
        'received': 0,
        'accepted': 0,
        'completed': 0,
      },
      'verification': <String, dynamic>{
        'status': 'draft',
        'adminReviewRequired': true,
      },
      'updatedAt': now,
    };

    await proRef.set(
      existing.exists
          ? baseProfile
          : <String, dynamic>{
              ...baseProfile,
              'status': 'pending',
              'plan': 'free_pro_trial',
              'termsAccepted': false,
              'createdAt': now,
            },
      SetOptions(merge: true),
    );
  }
}
