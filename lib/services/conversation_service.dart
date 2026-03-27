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
    String? currentUserName,
    String? otherUserName,
  }) async {
    final convCol = FirebaseFirestore.instance.collection('conversations');
    final normalizedCurrentUserName = _normalizeParticipantName(currentUserName);
    final normalizedOtherUserName = _normalizeParticipantName(otherUserName);
    final participantNames = <String, String>{
      currentUserId: normalizedCurrentUserName,
      otherUserId: normalizedOtherUserName,
    };

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
        await doc.reference.set({
          'participantNames': participantNames,
          'otherUserName': normalizedOtherUserName,
        }, SetOptions(merge: true));
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
        'participantNames': participantNames,
        'otherUserName': normalizedOtherUserName,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'unreadCount': {currentUserId: 0, otherUserId: 0},
      });
    });

    return conversationId;
  }

  static String _normalizeParticipantName(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? 'Utilisateur' : trimmed;
  }
}