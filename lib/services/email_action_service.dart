import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_functions_region.dart';

typedef EmailActionCallableInvoker = Future<void> Function(
  String functionName,
  Map<String, dynamic>? payload,
);

class EmailActionService {
  EmailActionService._();

  static final FirebaseFunctions _functions = prestoFirebaseFunctions;
  static EmailActionCallableInvoker _callableInvoker = _invokeFirebaseCallable;

  static Future<void> _invokeFirebaseCallable(
    String functionName,
    Map<String, dynamic>? payload,
  ) async {
    final callable = _functions.httpsCallable(functionName);
    if (payload == null) {
      await callable.call();
      return;
    }
    await callable.call(payload);
  }

  static void setCallableInvokerForTest(EmailActionCallableInvoker invoker) {
    _callableInvoker = invoker;
  }

  static void resetCallableInvokerForTest() {
    _callableInvoker = _invokeFirebaseCallable;
  }

  static Future<bool> syncCurrentUserEmailVerificationState({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) async {
    final effectiveAuth = auth ?? FirebaseAuth.instance;
    final currentUser = effectiveAuth.currentUser;
    if (currentUser == null) {
      return false;
    }

    try {
      await currentUser.reload();
    } catch (_) {
      // Best effort: continue with the freshest local state available.
    }

    final refreshedUser = effectiveAuth.currentUser ?? currentUser;
    final email = refreshedUser.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty || !refreshedUser.emailVerified) {
      return false;
    }

    final effectiveFirestore = firestore ?? FirebaseFirestore.instance;
    final userRef =
        effectiveFirestore.collection('users').doc(refreshedUser.uid);

    await refreshedUser.getIdToken(true);

    final payload = <String, dynamic>{
      'email': email,
      'emailVerified': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'email_verified': FieldValue.delete(),
      'isEmailVerified': FieldValue.delete(),
    };

    await userRef.set(<String, dynamic>{
      'uid': refreshedUser.uid,
      ...payload,
    }, SetOptions(merge: true));

    return true;
  }

  static Future<void> requestPasswordResetEmail(String email) async {
    await _callableInvoker(
      'requestPasswordResetEmail',
      <String, dynamic>{'email': email.trim()},
    );
  }

  static Future<void> requestEmailVerificationEmail() async {
    await _callableInvoker('requestEmailVerificationEmail', null);
  }

  static Future<void> reportPasswordChanged() async {
    await _callableInvoker('reportPasswordChanged', <String, dynamic>{
      'changedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
