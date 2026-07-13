class ChatRequestException implements Exception {
  const ChatRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Validation cliente alignée sur les limites autoritaires du backend.
/// Le backend conserve la décision finale et revérifie systématiquement.
class ChatRequestPolicy {
  const ChatRequestPolicy({this.maxMessageLength = 2000});

  final int maxMessageLength;

  String normalizeIdentifier(String value, {required String fieldName}) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ChatRequestException('$fieldName est requis.');
    }
    return normalized;
  }

  String normalizeMessage(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw const ChatRequestException('Le message ne peut pas être vide.');
    }
    if (normalized.length > maxMessageLength) {
      throw ChatRequestException(
        'Le message ne peut pas dépasser $maxMessageLength caractères.',
      );
    }
    return normalized;
  }

  String extractThreadId(dynamic responseData) {
    final data = responseData is Map
        ? Map<String, dynamic>.from(responseData.cast<String, dynamic>())
        : const <String, dynamic>{};
    final threadId =
        (data['threadId'] ?? data['conversationId'] ?? '').toString().trim();
    if (threadId.isEmpty) {
      throw const ChatRequestException(
        'La conversation n’a pas pu être créée.',
      );
    }
    return threadId;
  }
}
