import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service complet de messagerie avec Firebase Firestore
class MessagingService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  MessagingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Récupère ou crée une conversation entre deux utilisateurs
  Future<String> getOrCreateConversation({
    required String otherUserId,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('Utilisateur non connecté');

    // Recherche une conversation existante
    final query = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (final doc in query.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);

      if (participants.contains(otherUserId)) {
        return doc.id;
      }
    }

    // Crée une nouvelle conversation
    final docRef = await _firestore.collection('conversations').add({
      'participants': [currentUserId, otherUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageSenderId': '',
      'unreadCount': {
        currentUserId: 0,
        otherUserId: 0,
      },
    });

    return docRef.id;
  }

  /// Stream des conversations de l'utilisateur courant
  Stream<QuerySnapshot<Map<String, dynamic>>> getConversationsStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  /// Stream des messages d'une conversation
  Stream<QuerySnapshot<Map<String, dynamic>>> getMessagesStream(
    String conversationId,
  ) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots();
  }

  /// Envoie un message dans une conversation
  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('Utilisateur non connecté');

    if (text.trim().isEmpty) return;

    final batch = _firestore.batch();

    // Ajoute le message
    final messageRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();

    batch.set(messageRef, {
      'text': text.trim(),
      'senderId': currentUserId,
      'sentAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    // Met à jour la conversation
    final conversationRef =
        _firestore.collection('conversations').doc(conversationId);

    // Récupère les participants pour incrémenter le unreadCount du destinataire
    final conversationDoc = await conversationRef.get();
    final data = conversationDoc.data();
    final participants = List<String>.from(data?['participants'] ?? []);
    final otherUserId =
        participants.firstWhere((id) => id != currentUserId, orElse: () => '');

    batch.update(conversationRef, {
      'lastMessage': text.trim(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUserId,
      if (otherUserId.isNotEmpty)
        'unreadCount.$otherUserId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Marque tous les messages d'une conversation comme lus
  Future<void> markConversationAsRead(String conversationId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    await _firestore.collection('conversations').doc(conversationId).update({
      'unreadCount.$currentUserId': 0,
    });
  }

  /// Récupère les informations d'un utilisateur pour affichage
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  /// Récupère le nombre total de messages non lus
  Future<int> getTotalUnreadCount() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 0;

    final query = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .get();

    int total = 0;
    for (final doc in query.docs) {
      final data = doc.data();
      final unreadMap = data['unreadCount'] as Map<String, dynamic>?;
      final unread = unreadMap?[currentUserId] as int? ?? 0;
      total += unread;
    }

    return total;
  }

  /// Supprime une conversation (archive côté utilisateur)
  Future<void> archiveConversation(String conversationId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    await _firestore.collection('conversations').doc(conversationId).update({
      'archived.$currentUserId': true,
    });
  }

  /// Signale une conversation
  Future<void> reportConversation({
    required String conversationId,
    required String reason,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    await _firestore.collection('reports').add({
      'type': 'conversation',
      'conversationId': conversationId,
      'reportedBy': currentUserId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
}
