import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service centralisé pour gérer Firebase avec optimisations
class FirebaseService {
  FirebaseService._();
  static final instance = FirebaseService._();

  // Instances Firebase
  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  // ✅ État d'initialisation
  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialise Firebase avec optimisations
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // ✅ Configuration Firestore optimisée
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint('[Firestore] Settings configured');

      _initialized = true;
      debugPrint('[FirebaseService] Initialized successfully');
    } catch (e) {
      debugPrint('[FirebaseService] Init warning: $e');
      // Ne pas bloquer l'app si la persistence échoue
      _initialized = true;
    }
  }

  /// Stream d'auth state centralisé
  Stream<User?> get authStateChanges => auth.authStateChanges();

  /// Stream d'user changes (inclut metadata)
  Stream<User?> get userChanges => auth.userChanges();

  /// User actuel
  User? get currentUser => auth.currentUser;

  /// UID actuel (null si non connecté)
  String? get currentUserId => currentUser?.uid;

  /// Vérifie si l'utilisateur est connecté
  bool get isAuthenticated => currentUser != null;

  // ═══════════════════════════════════════════════════════════════
  // Collections Firestore (références centralisées)
  // ═══════════════════════════════════════════════════════════════

  /// Collection offers
  CollectionReference<Map<String, dynamic>> get offersCollection =>
      firestore.collection('offers');

  /// Collection users
  CollectionReference<Map<String, dynamic>> get usersCollection =>
      firestore.collection('users');

  /// Collection pros
  CollectionReference<Map<String, dynamic>> get prosCollection =>
      firestore.collection('pros');

  /// Collection conversations
  CollectionReference<Map<String, dynamic>> get conversationsCollection =>
      firestore.collection('conversations');

  /// Collection messages
  CollectionReference<Map<String, dynamic>> get messagesCollection =>
      firestore.collection('messages');

  /// Collection notifications
  CollectionReference<Map<String, dynamic>> get notificationsCollection =>
      firestore.collection('notifications');

  // ═══════════════════════════════════════════════════════════════
  // Méthodes utilitaires pour queries optimisées
  // ═══════════════════════════════════════════════════════════════

  /// Récupère une offre par ID (avec cache)
  Future<DocumentSnapshot<Map<String, dynamic>>> getOffer(String offerId) {
    return offersCollection.doc(offerId).get(const GetOptions(
          source: Source.serverAndCache,
        ));
  }

  /// Récupère un utilisateur par ID (avec cache)
  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String userId) {
    return usersCollection.doc(userId).get(const GetOptions(
          source: Source.serverAndCache,
        ));
  }

  /// Stream d'offres avec pagination optimisée
  Stream<QuerySnapshot<Map<String, dynamic>>> getOffersStream({
    String? category,
    String? dept,
    String? location,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> query = offersCollection;

    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    if (dept != null && dept.isNotEmpty) {
      query = query.where('dept', isEqualTo: dept);
    }

    if (location != null && location.isNotEmpty) {
      query = query.where('location', isEqualTo: location);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Stream de conversations pour un utilisateur
  Stream<QuerySnapshot<Map<String, dynamic>>> getConversationsStream(
      String userId) {
    return conversationsCollection
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Stream des messages d'une conversation
  Stream<QuerySnapshot<Map<String, dynamic>>> getMessagesStream(
      String conversationId) {
    return messagesCollection
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('createdAt', descending: false)
        .limit(100)
        .snapshots();
  }

  /// Stream des notifications pour un utilisateur
  Stream<QuerySnapshot<Map<String, dynamic>>> getNotificationsStream(
      String userId) {
    return notificationsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // ═══════════════════════════════════════════════════════════════
  // Batch operations optimisées
  // ═══════════════════════════════════════════════════════════════

  /// Crée un batch Firestore
  WriteBatch batch() => firestore.batch();

  /// Exécute plusieurs opérations en batch
  Future<void> executeBatch(void Function(WriteBatch batch) operations) async {
    final batch = this.batch();
    operations(batch);
    await batch.commit();
  }

  // ═══════════════════════════════════════════════════════════════
  // Gestion des erreurs Firebase
  // ═══════════════════════════════════════════════════════════════

  /// Convertit une FirebaseException en message utilisateur
  String getErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Accès refusé. Vérifiez vos permissions.';
        case 'not-found':
          return 'Document introuvable.';
        case 'already-exists':
          return 'Ce document existe déjà.';
        case 'resource-exhausted':
          return 'Quota dépassé. Réessayez plus tard.';
        case 'unauthenticated':
          return 'Veuillez vous connecter.';
        case 'unavailable':
          return 'Service temporairement indisponible.';
        case 'deadline-exceeded':
          return 'Délai d\'attente dépassé.';
        case 'cancelled':
          return 'Opération annulée.';
        default:
          return 'Erreur: ${error.code}';
      }
    }
    return error.toString();
  }

  /// Vérifie si une erreur Firebase est récupérable
  bool isRecoverableError(dynamic error) {
    if (error is! FirebaseException) return false;
    return ['unavailable', 'deadline-exceeded', 'resource-exhausted']
        .contains(error.code);
  }

  // ═══════════════════════════════════════════════════════════════
  // Méthodes de nettoyage
  // ═══════════════════════════════════════════════════════════════

  /// Vide le cache Firestore (utile pour debug)
  Future<void> clearCache() async {
    try {
      await firestore.clearPersistence();
      debugPrint('[Firestore] Cache cleared');
    } catch (e) {
      debugPrint('[Firestore] Clear cache failed: $e');
    }
  }

  /// Termine toutes les connexions Firebase
  Future<void> terminate() async {
    try {
      await firestore.terminate();
      _initialized = false;
      debugPrint('[Firestore] Terminated');
    } catch (e) {
      debugPrint('[Firestore] Terminate failed: $e');
    }
  }
}
