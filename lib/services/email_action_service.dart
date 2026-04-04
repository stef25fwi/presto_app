import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_functions_region.dart';

class EmailActionService {
  EmailActionService._();

  static final FirebaseFunctions _functions =
      prestoFirebaseFunctions;

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

    await FirebaseFirestore.instance
        .collection('users')
        .doc(refreshedUser.uid)
        .set({
      'email': email,
      'emailVerified': true,
      'email_verified': true,
      'isEmailVerified': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

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
