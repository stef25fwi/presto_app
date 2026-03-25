import 'package:cloud_functions/cloud_functions.dart';

class EmailActionService {
  EmailActionService._();

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

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