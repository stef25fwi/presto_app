import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Service pour gérer Firebase Cloud Messaging (notifications push)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  late RemoteMessage? _initialMessage;

  /// Initialise le service de notifications
  Future<void> initialize() async {
    // Demander les permissions
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('[Notifications] Permission status: ${settings.authorizationStatus}');

    // Handler pour les messages en background
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    // Handler pour les messages en foreground
    FirebaseMessaging.onMessage.listen(_foregroundHandler);

    // Handler pour les clics sur les notifications
    FirebaseMessaging.onMessageOpenedApp.listen(_messageOpenedHandler);

    // Récupérer le message initial (si l'app a été lancée depuis une notification)
    _initialMessage = await _messaging.getInitialMessage();
    if (_initialMessage != null) {
      _messageOpenedHandler(_initialMessage!);
    }

    // Récupérer et afficher le token FCM
    final token = await _messaging.getToken();
    debugPrint('[Notifications] FCM Token: $token');

    // S'abonner aux mises à jour du token
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('[Notifications] Nouveau token FCM: $newToken');
      // Envoyer le nouveau token au serveur/Firestore
      _saveFcmTokenToFirestore(newToken);
    });
  }

  /// Handler pour les messages reçus en background (app fermée)
  static Future<void> _backgroundHandler(RemoteMessage message) async {
    debugPrint('[Notifications-Background] Message reçu: ${message.messageId}');
    debugPrint('[Notifications-Background] Title: ${message.notification?.title}');
    debugPrint('[Notifications-Background] Body: ${message.notification?.body}');
    
    // Traiter le message
    _handleMessage(message);
  }

  /// Handler pour les messages reçus en foreground (app ouverte)
  void _foregroundHandler(RemoteMessage message) {
    debugPrint('[Notifications-Foreground] Message reçu: ${message.messageId}');
    debugPrint('[Notifications-Foreground] Title: ${message.notification?.title}');
    debugPrint('[Notifications-Foreground] Body: ${message.notification?.body}');
    
    // Afficher une notification locale ou mettre à jour l'UI
    if (message.notification != null) {
      debugPrint('[Notifications-Foreground] Contient une notification');
    }
  }

  /// Handler pour les clics sur les notifications
  void _messageOpenedHandler(RemoteMessage message) {
    debugPrint('[Notifications] Notification cliquée: ${message.messageId}');
    _handleMessage(message);
  }

  /// Traite un message
  static void _handleMessage(RemoteMessage message) {
    // Exemple : redirection basée sur le type de notification
    final messageData = message.data;
    
    if (messageData.containsKey('type')) {
      final type = messageData['type'];
      debugPrint('[Notifications] Type de notification: $type');
      
      // Redirection selon le type
      switch (type) {
        case 'new_message':
          debugPrint('[Notifications] Nouvelle notification de message');
          // Rediriger vers la page Messages
          break;
        case 'offer_update':
          debugPrint('[Notifications] Notification de mise à jour d\'offre');
          // Rediriger vers la page Offres
          break;
        default:
          debugPrint('[Notifications] Type inconnu: $type');
      }
    }
  }

  /// Sauvegarde le token FCM dans Firestore
  static void _saveFcmTokenToFirestore(String token) {
    // À implémenter selon votre structure Firestore
    debugPrint('[Notifications] Sauvegarde du token FCM: $token');
  }

  /// S'abonner à un topic (pour les notifications de groupe)
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('[Notifications] Abonné au topic: $topic');
  }

  /// Se désabonner d'un topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('[Notifications] Désabonné du topic: $topic');
  }

  /// Récupérer le token FCM actuel
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}
