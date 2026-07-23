import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'firebase_functions_region.dart';

typedef ConversationFunctionCaller = Future<Map<String, dynamic>> Function({
  required String name,
  required Duration timeout,
  required Map<String, dynamic> parameters,
});

class ConversationAttachmentInput {
  final String type;
  final String name;
  final String url;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;

  const ConversationAttachmentInput({
    required this.type,
    required this.name,
    required this.url,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'name': name,
      'url': url,
      'storagePath': storagePath,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
    };
  }
}

class ProcessedConversationPhoto {
  final String storagePath;
  final String downloadUrl;
  final String thumbnailUrl;
  final String mimeType;
  final int sizeBytes;

  const ProcessedConversationPhoto({
    required this.storagePath,
    required this.downloadUrl,
    required this.thumbnailUrl,
    required this.mimeType,
    required this.sizeBytes,
  });

  factory ProcessedConversationPhoto.fromMap(Map<String, dynamic> data) {
    return ProcessedConversationPhoto(
      storagePath: (data['storagePath'] ?? '').toString(),
      downloadUrl: (data['downloadUrl'] ?? '').toString(),
      thumbnailUrl:
          (data['thumbnailUrl'] ?? data['downloadUrl'] ?? '').toString(),
      mimeType: (data['mimeType'] ?? 'image/webp').toString(),
      sizeBytes: (data['sizeBytes'] is num)
          ? (data['sizeBytes'] as num).round()
          : int.tryParse((data['sizeBytes'] ?? '').toString()) ?? 0,
    );
  }
}

class ConversationService {
  static FirebaseFunctions _functions = prestoFirebaseFunctions;
  static ConversationFunctionCaller _caller = _callFirebaseFunction;

  static Future<Map<String, dynamic>> _callFirebaseFunction({
    required String name,
    required Duration timeout,
    required Map<String, dynamic> parameters,
  }) async {
    final response = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: name,
      timeout: timeout,
      parameters: parameters,
    );
    return Map<String, dynamic>.from(
      (response.data as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  @visibleForTesting
  static void setFunctionCallerForTesting(ConversationFunctionCaller? caller) {
    _caller = caller ?? _callFirebaseFunction;
  }

  @visibleForTesting
  static void setFirebaseFunctionsForTesting(FirebaseFunctions? functions) {
    _functions = functions ?? prestoFirebaseFunctions;
    _caller = _callFirebaseFunction;
  }

  static Future<String> ensureConversation({
    required String offerId,
    required String offerTitle,
    required String currentUserId,
    required String otherUserId,
    String? currentUserName,
    String? otherUserName,
  }) async {
    final data = await _caller(
      name: 'ensureOfferConversation',
      timeout: const Duration(seconds: 20),
      parameters: <String, dynamic>{
        'offerId': offerId,
        'offerTitle': offerTitle,
        'currentUserId': currentUserId,
        'otherUserId': otherUserId,
        'currentUserName': currentUserName,
        'otherUserName': otherUserName,
      },
    );

    final conversationId = (data['conversationId'] ?? '').toString().trim();
    if (conversationId.isEmpty) {
      throw StateError('Conversation introuvable');
    }
    return conversationId;
  }

  static Future<String> sendMessage({
    required String conversationId,
    String text = '',
    List<ConversationAttachmentInput> attachments = const [],
  }) async {
    final data = await _caller(
      name: 'sendConversationMessage',
      timeout: const Duration(seconds: 20),
      parameters: <String, dynamic>{
        'conversationId': conversationId,
        'text': text,
        if (attachments.isNotEmpty)
          'attachments': attachments.map((entry) => entry.toJson()).toList(),
      },
    );
    final resolvedConversationId =
        (data['conversationId'] ?? conversationId).toString().trim();
    return resolvedConversationId.isEmpty
        ? conversationId
        : resolvedConversationId;
  }

  static Future<ProcessedConversationPhoto> processConversationPhoto({
    required String conversationId,
    required String storagePath,
  }) async {
    final data = await _caller(
      name: 'processConversationAttachmentPhoto',
      timeout: const Duration(seconds: 60),
      parameters: <String, dynamic>{
        'conversationId': conversationId,
        'storagePath': storagePath,
      },
    );
    final processed = ProcessedConversationPhoto.fromMap(data);
    if (processed.storagePath.trim().isEmpty ||
        processed.downloadUrl.trim().isEmpty) {
      throw StateError('Photo de conversation non traitee.');
    }
    return processed;
  }

  static Future<void> markAsRead({
    required String conversationId,
  }) async {
    await _caller(
      name: 'markConversationRead',
      timeout: const Duration(seconds: 15),
      parameters: <String, dynamic>{
        'conversationId': conversationId,
      },
    );
  }

  static Future<void> archiveConversation({
    required String conversationId,
  }) async {
    await _caller(
      name: 'archiveConversation',
      timeout: const Duration(seconds: 15),
      parameters: <String, dynamic>{
        'conversationId': conversationId,
      },
    );
  }

  static Future<void> unarchiveConversation({
    required String conversationId,
  }) async {
    await _caller(
      name: 'unarchiveConversation',
      timeout: const Duration(seconds: 15),
      parameters: <String, dynamic>{
        'conversationId': conversationId,
      },
    );
  }

  static Future<void> blockConversation({
    required String conversationId,
  }) async {
    await _caller(
      name: 'blockConversation',
      timeout: const Duration(seconds: 15),
      parameters: <String, dynamic>{
        'conversationId': conversationId,
      },
    );
  }

  static Future<void> unblockConversation({
    required String conversationId,
  }) async {
    await _caller(
      name: 'unblockConversation',
      timeout: const Duration(seconds: 15),
      parameters: <String, dynamic>{
        'conversationId': conversationId,
      },
    );
  }

  static Future<void> adminUnblockConversation({
    required String conversationId,
  }) async {
    await _caller(
      name: 'adminUnblockConversation',
      timeout: const Duration(seconds: 20),
      parameters: <String, dynamic>{
        'conversationId': conversationId,
      },
    );
  }

  static Future<void> deleteConversation({
    required String conversationId,
  }) async {
    await _caller(
      name: 'deleteConversation',
      timeout: const Duration(seconds: 30),
      parameters: <String, dynamic>{
        'conversationId': conversationId,
      },
    );
  }

  static Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _caller(
      name: 'deleteConversationMessage',
      timeout: const Duration(seconds: 15),
      parameters: <String, dynamic>{
        'conversationId': conversationId,
        'messageId': messageId,
      },
    );
  }
}
