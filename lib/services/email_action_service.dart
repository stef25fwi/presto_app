import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_functions_region.dart';
import 'user_profile_bootstrap_service.dart';

class EmailActionService {
  EmailActionService._();

  static final FirebaseFunctions _functions = prestoFirebaseFunctions;

  static Future<bool> syncCurrentUserEmailVerificationState() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return false;
    }

    try {
      await currentUser.reload();
    } catch (_) {
      // Best effort: continue with the freshest local state available.
    }

    final refreshedUser = FirebaseAuth.instance.currentUser ?? currentUser;
    final email = refreshedUser.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty || !refreshedUser.emailVerified) {
      return false;
    }

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(refreshedUser.uid);

    await UserProfileBootstrapService.prepareProfileFirestoreAccess(
      user: refreshedUser,
      forceRefreshToken: true,
      forceRefreshAppCheckToken: true,
    );

    final payload = <String, dynamic>{
      'email': email,
      'emailVerified': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'email_verified': FieldValue.delete(),
      'isEmailVerified': FieldValue.delete(),
    };

    try {
      await userRef.update(payload);
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') {
        rethrow;
      }
      await userRef.set(<String, dynamic>{
        'uid': refreshedUser.uid,
        ...payload,
      });
    }

    return true;
  }

  static Future<void> requestPasswordResetEmail(String email) async {
    final callable = _functions.httpsCallable('requestPasswordResetEmail');
    await callable.call(<String, dynamic>{'email': email.trim()});
  }

  static Future<void> requestEmailVerificationEmail() async {
    final callable = _functions.httpsCallable('requestEmailVerificationEmail');
    await callable.call();
  }

  static Future<void> reportPasswordChanged() async {
    final callable = _functions.httpsCallable('reportPasswordChanged');
    await callable.call(<String, dynamic>{
      'changedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
