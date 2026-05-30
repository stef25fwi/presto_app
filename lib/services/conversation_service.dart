import 'package:cloud_functions/cloud_functions.dart';

import 'firebase_functions_region.dart';

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
  static final FirebaseFunctions _functions = prestoFirebaseFunctions;

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
    String text = '',
    List<ConversationAttachmentInput> attachments = const [],
  }) async {
    final callable = _functions.httpsCallable(
      'sendConversationMessage',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    await callable.call(<String, dynamic>{
      'conversationId': conversationId,
      'text': text,
      if (attachments.isNotEmpty)
        'attachments': attachments.map((entry) => entry.toJson()).toList(),
    });
  }

  static Future<ProcessedConversationPhoto> processConversationPhoto({
    required String conversationId,
    required String storagePath,
  }) async {
    final callable = _functions.httpsCallable(
      'processConversationAttachmentPhoto',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    final response = await callable.call(<String, dynamic>{
      'conversationId': conversationId,
      'storagePath': storagePath,
    });
    final data = Map<String, dynamic>.from(
      (response.data as Map?)?.cast<String, dynamic>() ?? const {},
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
    final callable = _functions.httpsCallable(
      'markConversationRead',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    await callable.call(<String, dynamic>{
      'conversationId': conversationId,
    });
  }

  static Future<void> archiveConversation({
    required String conversationId,
  }) async {
    final callable = _functions.httpsCallable(
      'archiveConversation',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    await callable.call(<String, dynamic>{
      'conversationId': conversationId,
    });
  }

  static Future<void> unarchiveConversation({
    required String conversationId,
  }) async {
    final callable = _functions.httpsCallable(
      'unarchiveConversation',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    await callable.call(<String, dynamic>{
      'conversationId': conversationId,
    });
  }

  static Future<void> blockConversation({
    required String conversationId,
  }) async {
    final callable = _functions.httpsCallable(
      'blockConversation',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    await callable.call(<String, dynamic>{
      'conversationId': conversationId,
    });
  }

  static Future<void> unblockConversation({
    required String conversationId,
  }) async {
    final callable = _functions.httpsCallable(
      'unblockConversation',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    await callable.call(<String, dynamic>{
      'conversationId': conversationId,
    });
  }

  static Future<void> deleteConversation({
    required String conversationId,
  }) async {
    final callable = _functions.httpsCallable(
      'deleteConversation',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    await callable.call(<String, dynamic>{
      'conversationId': conversationId,
    });
  }

  static Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final callable = _functions.httpsCallable(
      'deleteConversationMessage',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    await callable.call(<String, dynamic>{
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }
}
