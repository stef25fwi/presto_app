import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/user_profile_bootstrap_service.dart';

typedef AuthProfileTimestampFactory = Object Function();
typedef AuthProfileBootstrapAction = Future<void> Function({
  required User user,
  required String authMethod,
  required bool isNewUserHint,
  required bool forceRefresh,
});
typedef AuthProfileAccessPreparationAction = Future<void> Function({
  required User user,
  required bool forceRefreshToken,
  required bool forceRefreshAppCheckToken,
});
typedef AuthUserDocumentWriter = Future<void> Function({
  required String uid,
  required Map<String, dynamic> data,
});
typedef AuthBusinessProfileExistsReader = Future<bool> Function(String uid);
typedef AuthBusinessProfileWriter = Future<void> Function({
  required String uid,
  required Map<String, dynamic> data,
});

class AuthUserProfileService {
  AuthUserProfileService({
    FirebaseFirestore? firestore,
    AuthProfileTimestampFactory? timestampFactory,
    AuthProfileBootstrapAction? bootstrapUserProfile,
    AuthProfileAccessPreparationAction? prepareProfileAccess,
    AuthUserDocumentWriter? writeUserDocument,
    AuthBusinessProfileExistsReader? businessProfileExists,
    AuthBusinessProfileWriter? writeBusinessProfile,
  })  : _firestore = firestore,
        _timestampFactory =
            timestampFactory ?? (() => FieldValue.serverTimestamp()),
        _bootstrapUserProfile = bootstrapUserProfile,
        _prepareProfileAccess = prepareProfileAccess,
        _writeUserDocument = writeUserDocument,
        _businessProfileExists = businessProfileExists,
        _writeBusinessProfile = writeBusinessProfile;

  final FirebaseFirestore? _firestore;
  final AuthProfileTimestampFactory _timestampFactory;
  final AuthProfileBootstrapAction? _bootstrapUserProfile;
  final AuthProfileAccessPreparationAction? _prepareProfileAccess;
  final AuthUserDocumentWriter? _writeUserDocument;
  final AuthBusinessProfileExistsReader? _businessProfileExists;
  final AuthBusinessProfileWriter? _writeBusinessProfile;

  FirebaseFirestore get _resolvedFirestore =>
      _firestore ?? FirebaseFirestore.instance;

  Future<void> ensureEmailUserProfile({
    required User user,
    required String displayName,
    required bool isBusinessAccount,
  }) async {
    final bootstrap = _bootstrapUserProfile;
    if (bootstrap != null) {
      await bootstrap(
        user: user,
        authMethod: 'email',
        isNewUserHint: true,
        forceRefresh: true,
      );
    } else {
      await UserProfileBootstrapService.ensureUserDocument(
        user: user,
        authMethod: 'email',
        isNewUserHint: true,
        forceRefresh: true,
      );
    }

    final now = _timestampFactory();
    final email = user.email?.trim().toLowerCase() ?? '';
    final normalizedDisplayName = displayName.trim();
    final data = <String, dynamic>{
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
    };

    final writer = _writeUserDocument;
    if (writer != null) {
      await writer(uid: user.uid, data: data);
    } else {
      await _resolvedFirestore.collection('users').doc(user.uid).set(
            data,
            SetOptions(merge: true),
          );
    }

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
    final prepare = _prepareProfileAccess;
    if (prepare != null) {
      await prepare(
        user: user,
        forceRefreshToken: true,
        forceRefreshAppCheckToken: true,
      );
    } else {
      await UserProfileBootstrapService.prepareProfileFirestoreAccess(
        user: user,
        forceRefreshToken: true,
        forceRefreshAppCheckToken: true,
      );
    }

    final existsReader = _businessProfileExists;
    final exists = existsReader != null
        ? await existsReader(user.uid)
        : (await _resolvedFirestore.collection('pros').doc(user.uid).get())
            .exists;
    final now = _timestampFactory();
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
    final data = exists
        ? baseProfile
        : <String, dynamic>{
            ...baseProfile,
            'status': 'pending',
            'plan': 'free_pro_trial',
            'termsAccepted': false,
            'createdAt': now,
          };

    final writer = _writeBusinessProfile;
    if (writer != null) {
      await writer(uid: user.uid, data: data);
    } else {
      await _resolvedFirestore.collection('pros').doc(user.uid).set(
            data,
            SetOptions(merge: true),
          );
    }
  }
}
