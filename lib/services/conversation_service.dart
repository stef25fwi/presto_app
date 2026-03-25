import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationService {
  static String canonicalConversationId({
    required String offerId,
    required String currentUserId,
    required String otherUserId,
  }) {
    String sanitize(String value) => value.replaceAll('/', '_').trim();

    final participants = [sanitize(currentUserId), sanitize(otherUserId)]..sort();
    return 'offer_${sanitize(offerId)}__${participants.join('__')}';
  }

  static Future<String> ensureConversation({
    required String offerId,
    required String offerTitle,
    required String currentUserId,
    required String otherUserId,
  }) async {
    final convCol = FirebaseFirestore.instance.collection('conversations');

    final existing = await convCol
        .where('participants', arrayContains: currentUserId)
        .where('offerId', isEqualTo: offerId)
        .limit(20)
        .get();

    for (final doc in existing.docs) {
      final participants = (doc.data()['participants'] as List<dynamic>? ?? const [])
          .map((entry) => entry.toString())
          .toList();
      if (participants.contains(otherUserId)) {
        return doc.id;
      }
    }

    final conversationId = canonicalConversationId(
      offerId: offerId,
      currentUserId: currentUserId,
      otherUserId: otherUserId,
    );
    final participants = [currentUserId, otherUserId]..sort();
    final convRef = convCol.doc(conversationId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(convRef);
      if (snap.exists) return;

      transaction.set(convRef, {
        'offerId': offerId,
        'offerTitle': offerTitle,
        'participants': participants,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'unreadCount': {currentUserId: 0, otherUserId: 0},
      });
    });

    return conversationId;
  }
}