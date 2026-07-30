importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCXzhQcvFnlcApEhk8A-Y57IdQC8uO728c',
  authDomain: 'ilipresto.fr',
  projectId: 'presto-app-74abe',
  storageBucket: 'presto-app-74abe.firebasestorage.app',
  messagingSenderId: '151421230024',
  appId: '1:151421230024:web:1f974719da2f98822b3efd',
});

const messaging = firebase.messaging();

function normalizeRoute(data) {
  return data.routeName ||
    data.route_name ||
    (data.conversationId ? `/messages/${encodeURIComponent(data.conversationId)}` : '') ||
    (data.conversation_id ? `/messages/${encodeURIComponent(data.conversation_id)}` : '') ||
    (data.offerId ? `/offers/${encodeURIComponent(data.offerId)}` : '') ||
    (data.offer_id ? `/offers/${encodeURIComponent(data.offer_id)}` : '') ||
    '/';
}

function extractNotificationData(rawData) {
  const data = rawData || {};
  const fcmData =
    data.FCM_MSG && data.FCM_MSG.data && typeof data.FCM_MSG.data === 'object'
      ? data.FCM_MSG.data
      : {};
  return {
    ...fcmData,
    ...data,
  };
}

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const data = payload.data || {};

  const hasFirebaseVisibleNotification =
    Boolean(notification.title || notification.body);

  // Important :
  // Si le backend envoie un payload "notification", Firebase / le navigateur
  // affiche déjà la notification en arrière-plan. Appeler showNotification ici
  // crée un doublon visible. On ne montre manuellement que les messages data-only.
  if (hasFirebaseVisibleNotification) {
    console.debug('[FCM SW] Notification payload already visible; manual show skipped.');
    return;
  }

  const title = data.title || 'IliPresto';
  const body = data.body || data.message || '';
  const routeName = normalizeRoute(data);
  const tag =
    data.collapseKey ||
    data.collapse_key ||
    data.notificationId ||
    data.notification_id ||
    data.conversationId ||
    data.offerId ||
    'ilipresto_push';

  self.registration.showNotification(title, {
    body,
    tag,
    renotify: false,
    data: {
      ...data,
      routeName,
    },
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const data = extractNotificationData(event.notification.data || {});
  const routeName = normalizeRoute(data);
  const url = new URL(routeName, self.location.origin).toString();

  event.waitUntil((async () => {
    const windowClients = await clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });

    for (const client of windowClients) {
      if ('focus' in client) {
        client.navigate(url);
        return client.focus();
      }
    }

    return clients.openWindow(url);
  })());
});
