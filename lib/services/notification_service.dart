import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_init.dart';
import '../utils/runtime_action_logger.dart';
import 'firebase_functions_region.dart';

@pragma('vm:entry-point')
Future<void> prestoFirebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureFirebaseInitialized(source: 'messaging_background');
  debugPrint('[Notifications-Background] Message reçu: ${message.messageId}');
}

/// Service pour gérer Firebase Cloud Messaging (notifications push)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  // Must be injected at build time via --dart-define=FCM_WEB_VAPID_KEY=<key>
  static const String _webVapidKey =
      String.fromEnvironment('FCM_WEB_VAPID_KEY');
  static const String _messagingPromptDismissedAtKeyPrefix =
      'notifications.messaging_prompt.dismissed_at';
  static const AndroidNotificationChannel _messagesChannel =
      AndroidNotificationChannel(
    'ilipresto_messages',
    'Messages IliPresto',
    description: 'Nouveaux messages de la messagerie IliPresto.',
    importance: Importance.max,
  );
  static const AndroidNotificationChannel _activityChannel =
      AndroidNotificationChannel(
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
  final FirebaseFunctions _functions = prestoFirebaseFunctions;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<User?>? _authSubscription;
  GlobalKey<NavigatorState>? _navigatorKey;
  RemoteMessage? _initialMessage;
  String? _pendingRouteName;
  String? _lastRegisteredToken;
  String? _lastHandledMessageId;
  String? _lastVisibleNotificationKey;
  DateTime? _lastVisibleNotificationAt;
  String? _lastOpenedRouteName;
  DateTime? _lastOpenedRouteAt;
  AuthorizationStatus? _lastAuthorizationStatus;
  bool _initialized = false;
  bool _localNotificationsReady = false;
  bool _navigatorReady = false;
  bool _pendingRouteFlushScheduled = false;

  /// Initialise le service de notifications
  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    final navigatorChanged = _navigatorKey != navigatorKey;
    _navigatorKey = navigatorKey;
    if (navigatorChanged) {
      _navigatorReady = false;
    }
    if (!kIsWeb) {
      await ensureLocalNotificationsInitialized();
    }
    if (_initialized) {
      _schedulePendingRouteFlush();
      return;
    }

    final settings = await _messaging.getNotificationSettings();
    _lastAuthorizationStatus = settings.authorizationStatus;

    debugPrint(
        '[Notifications] Permission status: ${settings.authorizationStatus}');

    if (!kIsWeb) {
      await _messaging.setForegroundNotificationPresentationOptions(
        // Evite le double affichage smartphone :
        // - Firebase/iOS ne montre pas automatiquement la bannière en foreground.
        // - Flutter garde un seul affichage contrôlé via showForegroundNotification().
        alert: false,
        badge: false,
        sound: false,
      );
    }

    // Handler pour les messages en background
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        prestoFirebaseMessagingBackgroundHandler,
      );
    }

    // Handler pour les messages en foreground
    FirebaseMessaging.onMessage.listen((message) async {
      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint(
        '[Notifications-Foreground] currentUser=${currentUser?.uid} email=${currentUser?.email}',
      );
      debugPrint(
        '[Notifications-Foreground] route=${_resolveRouteName(message)} data=${message.data}',
      );
      if (_shouldSkipVisibleForegroundNotification(message)) {
        _foregroundHandler(message);
        return;
      }

      if (_shouldShowLocalForegroundNotification(message)) {
        await showForegroundNotification(message);
      }
      _foregroundHandler(message);
    });

    // Handler pour les clics sur les notifications
    FirebaseMessaging.onMessageOpenedApp.listen(_messageOpenedHandler);

    _authSubscription ??=
        FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) return;
      await syncPushRegistrationIfAuthorized();
    });

    // Récupérer le message initial (si l'app a été lancée depuis une notification)
    _initialMessage = await _messaging.getInitialMessage();
    if (_initialMessage != null) {
      _messageOpenedHandler(_initialMessage!);
    }

    // Récupérer et afficher le token FCM
    await syncPushRegistrationIfAuthorized();

    // S'abonner aux mises à jour du token
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[Notifications] Nouveau token FCM: $newToken');
      _lastRegisteredToken = newToken;
      if (await hasPushPermission()) {
        await _registerPushToken(newToken);
      }
    });

    _initialized = true;
    _schedulePendingRouteFlush();
  }

  String _readMessageDataValue(RemoteMessage message, String key) {
    final value = message.data[key];
    if (value == null) return '';
    return value.toString().trim();
  }

  String _visibleNotificationDedupeKey(RemoteMessage message) {
    final explicitKeys = [
      'notificationId',
      'notification_id',
      'messageId',
      'message_id',
      'conversationId',
      'conversation_id',
      'listingId',
      'listing_id',
      'routeName',
      'route_name',
    ];

    for (final key in explicitKeys) {
      final value = _readMessageDataValue(message, key);
      if (value.isNotEmpty) {
        return '$key:$value';
      }
    }

    final firebaseMessageId = message.messageId;
    if (firebaseMessageId != null && firebaseMessageId.trim().isNotEmpty) {
      return 'firebaseMessageId:${firebaseMessageId.trim()}';
    }

    final title =
        message.notification?.title ?? _readMessageDataValue(message, 'title');
    final body =
        message.notification?.body ?? _readMessageDataValue(message, 'body');
    final route = _resolveRouteName(message);

    return 'fallback:$route|$title|$body';
  }

  bool _shouldSkipVisibleForegroundNotification(RemoteMessage message) {
    final key = _visibleNotificationDedupeKey(message);
    final now = DateTime.now();

    final lastAt = _lastVisibleNotificationAt;
    final isRecentDuplicate = _lastVisibleNotificationKey == key &&
        lastAt != null &&
        now.difference(lastAt).inSeconds < 10;

    if (isRecentDuplicate) {
      debugPrint('[Notifications] Doublon visible ignoré: $key');
      return true;
    }

    _lastVisibleNotificationKey = key;
    _lastVisibleNotificationAt = now;
    return false;
  }

  bool _isAuthorizedStatus(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  Future<NotificationSettings> getPermissionSettings() {
    return _messaging.getNotificationSettings().then((settings) {
      _lastAuthorizationStatus = settings.authorizationStatus;
      return settings;
    });
  }

  Future<bool> hasPushPermission() async {
    final settings = await getPermissionSettings();
    return _isAuthorizedStatus(settings.authorizationStatus);
  }

  Future<bool> requestPushPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    final granted = _isAuthorizedStatus(settings.authorizationStatus);
    _lastAuthorizationStatus = settings.authorizationStatus;
    debugPrint(
      '[Notifications] request permission status=${settings.authorizationStatus}',
    );
    if (granted) {
      return await syncPushRegistrationIfAuthorized();
    }
    return granted;
  }

  Future<bool> syncPushRegistrationIfAuthorized() async {
    if (!await hasPushPermission()) return false;

    final token = await _fetchMessagingToken();
    debugPrint('[Notifications] FCM Token: $token');
    if (token == null) return false;

    _lastRegisteredToken = token;
    await _registerPushToken(token);
    return true;
  }

  String pushActivationFailureMessage() {
    if (_lastAuthorizationStatus == AuthorizationStatus.denied) {
      return 'Les notifications sont bloquées dans ce navigateur. Autorisez-les dans les réglages du site puis réessayez.';
    }
    if (kIsWeb && _webVapidKey.isEmpty) {
      return 'Les notifications web ne peuvent pas être activées tant que FCM_WEB_VAPID_KEY n’est pas configurée au build.';
    }
    return 'La permission a été accordée, mais le canal push n’a pas pu être finalisé. Réessayez ou vérifiez la configuration FCM.';
  }

  Future<bool> shouldPromptForMessagingPermission(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return false;

    final settings = await getPermissionSettings();
    if (_isAuthorizedStatus(settings.authorizationStatus)) {
      return false;
    }
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final dismissedAt =
        prefs.getInt(_messagingPromptDismissedAtKey(normalizedUserId)) ?? 0;
    if (dismissedAt <= 0) return true;

    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(dismissedAt),
    );
    return elapsed >= const Duration(days: 3);
  }

  Future<void> markMessagingPermissionPromptDismissed(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _messagingPromptDismissedAtKey(normalizedUserId),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> clearMessagingPermissionPromptDismissed(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_messagingPromptDismissedAtKey(normalizedUserId));
  }

  String _messagingPromptDismissedAtKey(String userId) {
    return '$_messagingPromptDismissedAtKeyPrefix.$userId';
  }

  void markNavigatorReady() {
    _navigatorReady = true;
    _schedulePendingRouteFlush();
  }

  Future<void> ensureLocalNotificationsInitialized() async {
    if (kIsWeb) return;
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

  bool _shouldShowLocalForegroundNotification(RemoteMessage message) {
    if (kIsWeb) return false;
    if (message.notification == null) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  Future<void> showForegroundNotification(RemoteMessage message) async {
    if (kIsWeb) return;
    await ensureLocalNotificationsInitialized();
    final notification = message.notification;
    if (notification == null) return;

    final routeName = _resolveRouteName(message);
    final requestedChannelId =
        (message.data['channelId'] ?? '').toString().trim();
    final channel = requestedChannelId == _messagesChannel.id
        ? _messagesChannel
        : _activityChannel;

    debugPrint(
      '[Notifications-Foreground] local notification channel=${channel.id} title=${notification.title} body=${notification.body}',
    );

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
    final messageId = message.messageId?.trim();
    if (messageId != null && messageId.isNotEmpty) {
      if (_lastHandledMessageId == messageId) {
        debugPrint('[Notifications] Message déjà traité: $messageId');
        return;
      }
      _lastHandledMessageId = messageId;
    }
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
    final token = await Future<String?>.value(
      _lastRegisteredToken,
    ).then((cachedToken) async {
      if (cachedToken != null && cachedToken.isNotEmpty) {
        return cachedToken;
      }
      return _fetchMessagingToken();
    }).timeout(
      const Duration(seconds: 4),
      onTimeout: () => null,
    );
    if (token == null) return;

    try {
      final callable = _functions.httpsCallable(
        'unregisterPushToken',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 10),
        ),
      );
      await callable.call(<String, dynamic>{'token': token}).timeout(
        const Duration(seconds: 6),
      );
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
        'platform': kIsWeb
            ? 'web-${defaultTargetPlatform.name}'
            : defaultTargetPlatform.name,
      });
    } catch (error) {
      debugPrint('[Notifications] register push token error: $error');
    }
  }

  Future<String?> _fetchMessagingToken() async {
    try {
      if (kIsWeb) {
        if (_webVapidKey.isEmpty) {
          debugPrint(
            '[Notifications] Web push disabled: FCM_WEB_VAPID_KEY non configure.',
          );
          return null;
        }
        final token = await _messaging.getToken(vapidKey: _webVapidKey);
        if (token == null) {
          debugPrint(
            '[Notifications] Web FCM token null: permission=${_lastAuthorizationStatus ?? 'unknown'} vapidConfigured=${_webVapidKey.isNotEmpty}',
          );
        }
        return token;
      }

      return await _messaging.getToken();
    } catch (error) {
      debugPrint('[Notifications] getToken error: $error');
      return null;
    }
  }

  String _resolveRouteName(RemoteMessage message) {
    final type = (message.data['type'] ?? '').toString().trim();
    final conversationId =
        (message.data['conversationId'] ?? '').toString().trim();
    final routeName = (message.data['routeName'] ?? '').toString().trim();

    if (conversationId.isNotEmpty &&
        (type == 'new_message' ||
            type == 'new_chat_message' ||
            routeName.startsWith('/messages/') ||
            routeName.startsWith('/chat/'))) {
      return '/messages/${Uri.encodeComponent(conversationId)}';
    }

    if (routeName.startsWith('/chat/')) {
      final segments =
          Uri.tryParse(routeName)?.pathSegments ?? const <String>[];
      if (segments.length >= 2 && segments[1].trim().isNotEmpty) {
        return '/messages/${Uri.encodeComponent(segments[1].trim())}';
      }
    }

    if (routeName.isNotEmpty) return routeName;

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
    if (!_navigatorReady || navigator == null) {
      logRuntimeAction(
        area: 'notifications',
        action: 'queue-route',
        details: <String, Object?>{
          'route': safeRoute,
        },
      );
      _pendingRouteName = safeRoute;
      _schedulePendingRouteFlush();
      return;
    }

    _pushRoute(navigator, safeRoute);
  }

  void _pushRoute(NavigatorState navigator, String routeName) {
    final now = DateTime.now();
    if (_lastOpenedRouteName == routeName &&
        _lastOpenedRouteAt != null &&
        now.difference(_lastOpenedRouteAt!) < const Duration(seconds: 2)) {
      debugPrint('[Notifications] Route déjà ouverte récemment: $routeName');
      return;
    }

    _lastOpenedRouteName = routeName;
    _lastOpenedRouteAt = now;
    _pendingRouteName = null;
    logRuntimeAction(
      area: 'notifications',
      action: 'push-route',
      details: <String, Object?>{
        'route': routeName,
      },
    );
    navigator.pushNamed(routeName);
  }

  void _schedulePendingRouteFlush() {
    if (_pendingRouteFlushScheduled) return;
    _pendingRouteFlushScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingRouteFlushScheduled = false;
      final routeName = _pendingRouteName;
      final navigator = _navigatorKey?.currentState;
      if (routeName == null) return;
      if (!_navigatorReady || navigator == null) {
        Future<void>.delayed(
          const Duration(milliseconds: 120),
          _schedulePendingRouteFlush,
        );
        return;
      }

      _pushRoute(navigator, routeName);
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
    return await _fetchMessagingToken();
  }
}
