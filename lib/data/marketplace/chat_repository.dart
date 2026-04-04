import 'package:cloud_functions/cloud_functions.dart';

import '../../services/firebase_functions_region.dart';

class ChatRepository {
  ChatRepository({FirebaseFunctions? functions})
      : _functions = functions ?? prestoFirebaseFunctions;

  final FirebaseFunctions _functions;

  Future<String> createThreadFromListing({
    required String listingId,
    required String firstMessage,
    required String recaptchaToken,
  }) async {
    final callable = _functions.httpsCallable(
      'createChatThreadFromListing',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    final response = await callable.call(<String, dynamic>{
      'listingId': listingId,
      'message': firstMessage,
      'recaptchaToken': recaptchaToken,
    });
    final data = Map<String, dynamic>.from(
      (response.data as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
    );
    return (data['threadId'] ?? '').toString().trim();
  }

  Future<void> sendMessage({
    required String threadId,
    required String message,
  }) async {
    final callable = _functions.httpsCallable(
      'sendChatMessage',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    await callable.call(<String, dynamic>{
      'threadId': threadId,
      'message': message,
    });
  }
}