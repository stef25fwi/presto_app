import 'package:cloud_functions/cloud_functions.dart';

class ConversationService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  static Future<String> ensureConversation({
    required String offerId,
    required String offerTitle,
    required String currentUserId,
    required String otherUserId,
    String? currentUserName,
    String? otherUserName,
  }) async {
    final callable = _functions.httpsCallable(
      'ensureOfferConversation',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    final response = await callable.call(<String, dynamic>{
      'offerId': offerId,
      'offerTitle': offerTitle,
      'currentUserId': currentUserId,
      'otherUserId': otherUserId,
      'currentUserName': currentUserName,
      'otherUserName': otherUserName,
    });

    final data = Map<String, dynamic>.from(
      (response.data as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final conversationId = (data['conversationId'] ?? '').toString().trim();
    if (conversationId.isEmpty) {
      throw StateError('Conversation introuvable');
    }
    return conversationId;
  }

  static Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final callable = _functions.httpsCallable(
      'sendConversationMessage',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    await callable.call(<String, dynamic>{
      'conversationId': conversationId,
      'text': text,
    });
  }

  static Future<void> markAsRead({
    required String conversationId,
  }) async {
    final callable = _functions.httpsCallable(
      'markConversationRead',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    await callable.call(<String, dynamic>{
      'conversationId': conversationId,
    });
  }
}