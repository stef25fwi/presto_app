import 'package:cloud_functions/cloud_functions.dart';

import '../../services/firebase_functions_region.dart';
import '../../services/marketplace_human_verification.dart';

class ChatRepository {
  ChatRepository({
    FirebaseFunctions? functions,
    MarketplaceHumanVerification? verification,
  })  : _functions = functions ?? prestoFirebaseFunctions,
        _verification = verification ?? const MarketplaceHumanVerification();

  final FirebaseFunctions _functions;
  final MarketplaceHumanVerification _verification;

  Future<String> createThreadFromListing({
    required String listingId,
    required String firstMessage,
    String? recaptchaToken,
  }) async {
    final token = (recaptchaToken ?? '').trim().isNotEmpty
        ? recaptchaToken!.trim()
        : await _verification.obtainToken(
            MarketplaceHumanVerificationAction.chatFirstMessage,
          );
    final response = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'createChatThreadFromListing',
      timeout: const Duration(seconds: 20),
      parameters: <String, dynamic>{
        'listingId': listingId,
        'message': firstMessage,
        'recaptchaToken': token,
      },
    );
    final data = Map<String, dynamic>.from(
      (response.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    return (data['threadId'] ?? '').toString().trim();
  }

  Future<void> sendMessage({
    required String threadId,
    required String message,
  }) async {
    await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'sendChatMessage',
      timeout: const Duration(seconds: 20),
      parameters: <String, dynamic>{
        'threadId': threadId,
        'message': message,
      },
    );
  }
}
