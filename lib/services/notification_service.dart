import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> prestoFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    await Firebase.initializeApp();
  }
  await NotificationService().ensureLocalNotificationsInitialized();
  await NotificationService().showForegroundNotification(message);
}

/// Service pour gérer Firebase Cloud Messaging (notifications push)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static const AndroidNotificationChannel _messagesChannel = AndroidNotificationChannel(
    'ilipresto_messages',
    'Messages IliPresto',
    description: 'Nouveaux messages de la messagerie IliPresto.',
    importance: Importance.max,
  );
  static const AndroidNotificationChannel _activityChannel = AndroidNotificationChannel(
    'ilipresto_activity',
    'Activité IliPresto',
    description: 'Nouvelles annonces et notifications produit IliPresto.',
    importance: Importance.high,
  );

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<User?>? _authSubscription;
  GlobalKey<NavigatorState>? _navigatorKey;
  RemoteMessage? _initialMessage;
  String? _pendingRouteName;
  String? _lastRegisteredToken;
  bool _initialized = false;
  bool _localNotificationsReady = false;

  /// Initialise le service de notifications
  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;
    await ensureLocalNotificationsInitialized();
    if (_initialized) {
      _schedulePendingRouteFlush();
      return;
    }

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

    debugPrint(
        '[Notifications] Permission status: ${settings.authorizationStatus}');

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handler pour les messages en background
    FirebaseMessaging.onBackgroundMessage(
      prestoFirebaseMessagingBackgroundHandler,
    );

    // Handler pour les messages en foreground
    FirebaseMessaging.onMessage.listen((message) async {
      await showForegroundNotification(message);
      _foregroundHandler(message);
    });

    // Handler pour les clics sur les notifications
    FirebaseMessaging.onMessageOpenedApp.listen(_messageOpenedHandler);

    _authSubscription ??=
        FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) return;
      final token = await _messaging.getToken();
      if (token != null) {
        _lastRegisteredToken = token;
        await _registerPushToken(token);
      }
    });

    // Récupérer le message initial (si l'app a été lancée depuis une notification)
    _initialMessage = await _messaging.getInitialMessage();
    if (_initialMessage != null) {
      _messageOpenedHandler(_initialMessage!);
    }

    // Récupérer et afficher le token FCM
    final token = await _messaging.getToken();
    debugPrint('[Notifications] FCM Token: $token');
    if (token != null) {
      _lastRegisteredToken = token;
      await _registerPushToken(token);
    }

    // S'abonner aux mises à jour du token
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[Notifications] Nouveau token FCM: $newToken');
      _lastRegisteredToken = newToken;
      await _registerPushToken(newToken);
    });

    _initialized = true;
    _schedulePendingRouteFlush();
  }

  Future<void> ensureLocalNotificationsInitialized() async {
    if (_localNotificationsReady) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = (response.payload ?? '').trim();
        if (payload.isNotEmpty) {
          _openRoute(payload);
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_messagesChannel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_activityChannel);

    _localNotificationsReady = true;
  }

  /// Handler pour les messages reçus en background (app fermée)
  static Future<void> _backgroundHandler(RemoteMessage message) async {
    debugPrint('[Notifications-Background] Message reçu: ${message.messageId}');
    debugPrint(
        '[Notifications-Background] Title: ${message.notification?.title}');
    debugPrint(
        '[Notifications-Background] Body: ${message.notification?.body}');

    // Traiter le message
    _handleMessage(message);
  }

  /// Handler pour les messages reçus en foreground (app ouverte)
  void _foregroundHandler(RemoteMessage message) {
    debugPrint('[Notifications-Foreground] Message reçu: ${message.messageId}');
    debugPrint(
        '[Notifications-Foreground] Title: ${message.notification?.title}');
    debugPrint(
        '[Notifications-Foreground] Body: ${message.notification?.body}');

    // Afficher une notification locale ou mettre à jour l'UI
    if (message.notification != null) {
      debugPrint('[Notifications-Foreground] Contient une notification');
    }
  }

  Future<void> showForegroundNotification(RemoteMessage message) async {
    await ensureLocalNotificationsInitialized();
    final notification = message.notification;
    if (notification == null) return;

    final routeName = _resolveRouteName(message);
    final requestedChannelId = (message.data['channelId'] ?? '').toString().trim();
    final channel = requestedChannelId == _messagesChannel.id
        ? _messagesChannel
        : _activityChannel;

    await _localNotifications.show(
      message.messageId.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: routeName,
    );
  }

  /// Handler pour les clics sur les notifications
  void _messageOpenedHandler(RemoteMessage message) {
    debugPrint('[Notifications] Notification cliquée: ${message.messageId}');
    _handleMessage(message);
  }

  /// Traite un message
  static void _handleMessage(RemoteMessage message) {
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

    NotificationService()._openRouteFromMessage(message);
  }

  Future<void> detachCurrentDevice() async {
    final token = _lastRegisteredToken ?? await _messaging.getToken();
    if (token == null) return;

    try {
      final callable = _functions.httpsCallable(
        'unregisterPushToken',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 10),
        ),
      );
      await callable.call(<String, dynamic>{'token': token});
    } catch (error) {
      debugPrint('[Notifications] unregister push token error: $error');
    }
  }

  Future<void> _registerPushToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final callable = _functions.httpsCallable(
        'registerPushToken',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 10),
        ),
      );
      await callable.call(<String, dynamic>{
        'token': token,
        'platform': defaultTargetPlatform.name,
      });
    } catch (error) {
      debugPrint('[Notifications] register push token error: $error');
    }
  }

  String _resolveRouteName(RemoteMessage message) {
    final routeName = (message.data['routeName'] ?? '').toString().trim();
    if (routeName.isNotEmpty) return routeName;

    final conversationId = (message.data['conversationId'] ?? '').toString().trim();
    if (conversationId.isNotEmpty) {
      return '/messages/${Uri.encodeComponent(conversationId)}';
    }

    final offerId = (message.data['offerId'] ?? '').toString().trim();
    if (offerId.isNotEmpty) {
      return '/offers/${Uri.encodeComponent(offerId)}';
    }

    return '';
  }

  void _openRouteFromMessage(RemoteMessage message) {
    final routeName = _resolveRouteName(message);
    if (routeName.isEmpty) return;
    _openRoute(routeName);
  }

  void _openRoute(String routeName) {
    final safeRoute = routeName.trim();
    if (safeRoute.isEmpty) return;

    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      _pendingRouteName = safeRoute;
      _schedulePendingRouteFlush();
      return;
    }

    _pendingRouteName = null;
    navigator.pushNamed(safeRoute);
  }

  void _schedulePendingRouteFlush() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeName = _pendingRouteName;
      final navigator = _navigatorKey?.currentState;
      if (routeName == null || navigator == null) return;

      _pendingRouteName = null;
      navigator.pushNamed(routeName);
    });
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
