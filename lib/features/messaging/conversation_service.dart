import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationInitResult {
  final String conversationId;
  final bool isNew;

  const ConversationInitResult({
    required this.conversationId,
    required this.isNew,
  });
}

class ConversationService {
  final FirebaseFirestore _firestore;

  ConversationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Retourne l'ID de conversation entre 2 utilisateurs.
  /// Crée la conversation si elle n'existe pas.
  Future<ConversationInitResult> getOrCreateConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final convs = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (final doc in convs.docs) {
      final data = doc.data();
      final participants = (data['participants'] is List)
          ? List<String>.from(data['participants'] as List)
          : const <String>[];

      if (participants.contains(otherUserId)) {
        return ConversationInitResult(conversationId: doc.id, isNew: false);
      }
    }

    final doc = await _firestore.collection('conversations').add({
      'participants': [currentUserId, otherUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'unreadCount': {currentUserId: 0, otherUserId: 0},
    });

    return ConversationInitResult(conversationId: doc.id, isNew: true);
  }

  Future<String> getOrCreateConversationId({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final result = await getOrCreateConversation(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
    );
    return result.conversationId;
  }
}
