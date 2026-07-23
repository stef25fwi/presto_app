import 'package:cloud_functions/cloud_functions.dart';

import '../../services/firebase_functions_region.dart';
import '../../services/marketplace_human_verification.dart';
import 'chat_request_policy.dart';

typedef ChatRepositoryCaller = Future<Object?> Function({
  required String name,
  required Duration timeout,
  required Map<String, dynamic> parameters,
});

typedef ChatVerificationTokenProvider = Future<String> Function(
    MarketplaceHumanVerificationAction action);

class ChatRepository {
  ChatRepository({
    FirebaseFunctions? functions,
    MarketplaceHumanVerification? verification,
    ChatRequestPolicy? requestPolicy,
    ChatRepositoryCaller? caller,
    ChatVerificationTokenProvider? verificationTokenProvider,
  })  : _functions = functions,
        _verification = verification ?? const MarketplaceHumanVerification(),
        _requestPolicy = requestPolicy ?? const ChatRequestPolicy(),
        _caller = caller,
        _verificationTokenProvider = verificationTokenProvider;

  final FirebaseFunctions? _functions;
  final MarketplaceHumanVerification _verification;
  final ChatRequestPolicy _requestPolicy;
  final ChatRepositoryCaller? _caller;
  final ChatVerificationTokenProvider? _verificationTokenProvider;

  Future<String> createThreadFromListing({
    required String listingId,
    required String firstMessage,
    String? recaptchaToken,
  }) async {
    final normalizedListingId = _requestPolicy.normalizeIdentifier(
      listingId,
      fieldName: 'listingId',
    );
    final normalizedMessage = _requestPolicy.normalizeMessage(firstMessage);
    final token = (recaptchaToken ?? '').trim().isNotEmpty
        ? recaptchaToken!.trim()
        : await _obtainVerificationToken(
            MarketplaceHumanVerificationAction.chatFirstMessage,
          );
    final data = await _call(
      name: 'createChatThreadFromListing',
      timeout: const Duration(seconds: 20),
      parameters: <String, dynamic>{
        'listingId': normalizedListingId,
        'message': normalizedMessage,
        'recaptchaToken': token,
      },
    );
    return _requestPolicy.extractThreadId(data);
  }

  Future<void> sendMessage({
    required String threadId,
    required String message,
  }) async {
    final normalizedThreadId = _requestPolicy.normalizeIdentifier(
      threadId,
      fieldName: 'threadId',
    );
    final normalizedMessage = _requestPolicy.normalizeMessage(message);
    await _call(
      name: 'sendChatMessage',
      timeout: const Duration(seconds: 20),
      parameters: <String, dynamic>{
        'threadId': normalizedThreadId,
        'message': normalizedMessage,
      },
    );
  }

  Future<String> _obtainVerificationToken(
    MarketplaceHumanVerificationAction action,
  ) =>
      (_verificationTokenProvider ?? _verification.obtainToken)(action);

  Future<Object?> _call({
    required String name,
    required Duration timeout,
    required Map<String, dynamic> parameters,
  }) async {
    final caller = _caller;
    if (caller != null) {
      return caller(name: name, timeout: timeout, parameters: parameters);
    }
    final response = await callPrestoFunction<dynamic>(
      functions: _functions ?? prestoFirebaseFunctions,
      name: name,
      timeout: timeout,
      parameters: parameters,
    );
    return response.data;
  }
}
